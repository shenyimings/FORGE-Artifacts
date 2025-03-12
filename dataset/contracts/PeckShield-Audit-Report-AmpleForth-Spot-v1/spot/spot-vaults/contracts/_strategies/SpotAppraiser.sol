// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITranche } from "@ampleforthorg/spot-contracts/contracts/_interfaces/buttonwood/ITranche.sol";
import { IBondController } from "@ampleforthorg/spot-contracts/contracts/_interfaces/buttonwood/IBondController.sol";
import { IPerpetualTranche } from "@ampleforthorg/spot-contracts/contracts/_interfaces/IPerpetualTranche.sol";
import { IChainlinkOracle } from "../_interfaces/external/IChainlinkOracle.sol";
import { IAmpleforthOracle } from "../_interfaces/external/IAmpleforthOracle.sol";
import { ISpotPricingStrategy } from "../_interfaces/ISpotPricingStrategy.sol";
import { InvalidSeniorCDRBound } from "../_interfaces/BillBrokerErrors.sol";

/**
 * @title SpotAppraiser
 *
 * @notice Pricing strategy adapter for a BillBroker vault which accepts
 *         SPOT (as the perp token) and dollar tokens like USDC.
 *
 *         AMPL is the underlying token for SPOT.
 *         The market price of AMPL is mean reverting and eventually converges to its target.
 *         However, it can significantly deviate from the target in the near term.
 *
 *         SPOT is a perpetual claim on AMPL senior tranches. Insofar as SPOT is fully backed by
 *         healthy senior tranches, we can price spot reliably using the following strategy:
 *
 *         SPOT_PRICE = MULTIPLIER * AMPL_TARGET
 *         MULTIPLIER = spot.getTVL() / spot.totalSupply(), which is it's enrichment/debasement factor.
 *         To know more, read the spot documentation.
 *
 *         We get the AMPL target price from Ampleforth's CPI oracle,
 *         which is also used by the protocol to adjust AMPL supply through rebasing.
 *
 *         And the MULTIPLIER is directly queried from the SPOT contract.
 *
 */
contract SpotAppraiser is Ownable, ISpotPricingStrategy {
    //-------------------------------------------------------------------------
    // Libraries
    using Math for uint256;

    //-------------------------------------------------------------------------
    // Constants & Immutables

    uint256 private constant DECIMALS = 18;
    uint256 private constant ONE = (10 ** DECIMALS);
    uint256 private constant SPOT_DR_DECIMALS = 8;
    uint256 private constant SPOT_DR_ONE = (10 ** SPOT_DR_DECIMALS);
    uint256 public constant CL_ORACLE_DECIMALS = 8;
    uint256 public constant CL_ORACLE_STALENESS_THRESHOLD_SEC = 3600 * 48; // 2 days
    uint256 public constant USD_UPPER_BOUND = (101 * ONE) / 100; // 1.01$
    uint256 public constant USD_LOWER_BOUND = (99 * ONE) / 100; // 0.99$
    uint256 public constant AMPL_DUST_AMT = 25000 * (10 ** 9); // 25000 AMPL

    /// @notice Address of the SPOT (perpetual tranche) ERC-20 token contract.
    IPerpetualTranche public immutable SPOT;

    /// @notice Address of the AMPL ERC-20 token contract.
    IERC20 public immutable AMPL;

    /// @notice Address of the USD token market price oracle.
    IChainlinkOracle public immutable USD_ORACLE;

    /// @notice Number of decimals representing the prices returned by the chainlink oracle.
    uint256 public immutable USD_ORACLE_DECIMALS;

    /// @notice Address of the Ampleforth CPI oracle. (provides the inflation-adjusted target price for AMPL).
    IAmpleforthOracle public immutable AMPL_CPI_ORACLE;

    /// @notice Number of decimals representing the prices returned by the ampleforth oracle.
    uint256 public immutable AMPL_CPI_ORACLE_DECIMALS;

    //-------------------------------------------------------------------------
    // Storage

    /// @notice The minimum "deviation ratio" of the SPOT outside which it's considered unhealthy.
    uint256 public minSPOTDR;

    /// @notice The minimum CDR of senior tranches backing SPOT outside which it's considered unhealthy.
    uint256 public minSeniorCDR;

    //-----------------------------------------------------------------------------
    // Constructor

    /// @notice Contract constructor.
    /// @param spot Address of the SPOT token.
    /// @param usdOracle Address of the USD token market price oracle token.
    /// @param cpiOracle Address of the Ampleforth CPI oracle.
    constructor(
        IPerpetualTranche spot,
        IChainlinkOracle usdOracle,
        IAmpleforthOracle cpiOracle
    ) Ownable() {
        SPOT = spot;
        AMPL = IERC20(address(spot.underlying()));

        USD_ORACLE = usdOracle;
        USD_ORACLE_DECIMALS = usdOracle.decimals();

        AMPL_CPI_ORACLE = cpiOracle;
        AMPL_CPI_ORACLE_DECIMALS = cpiOracle.DECIMALS();

        minSPOTDR = (ONE * 8) / 10; // 0.8
        minSeniorCDR = (ONE * 11) / 10; // 110%
    }

    //--------------------------------------------------------------------------
    // Owner only methods

    /// @notice Controls the minimum `deviationRatio` ratio of SPOT below which SPOT is considered unhealthy.
    /// @param minSPOTDR_ The minimum SPOT `deviationRatio`.
    function updateMinSPOTDR(uint256 minSPOTDR_) external onlyOwner {
        minSPOTDR = minSPOTDR_;
    }

    /// @notice Controls the minimum CDR of SPOT's senior tranche below which SPOT is considered unhealthy.
    /// @param minSeniorCDR_ The minimum senior tranche CDR.
    function updateMinPerpCollateralCDR(uint256 minSeniorCDR_) external onlyOwner {
        if (minSeniorCDR_ < ONE) {
            revert InvalidSeniorCDRBound();
        }
        minSeniorCDR = minSeniorCDR_;
    }

    //--------------------------------------------------------------------------
    // External methods

    /// @return p The price of the usd token in dollars.
    /// @return v True if the price is valid and can be used by downstream consumers.
    function usdPrice() external view override returns (uint256, bool) {
        (uint256 p, bool v) = _getCLOracleData(USD_ORACLE, USD_ORACLE_DECIMALS);
        // If the market price of the USD coin deviated too much from 1$,
        // it's an indication of some systemic issue with the USD token
        // and thus its price should be considered unreliable.
        return (ONE, (v && p < USD_UPPER_BOUND && p > USD_LOWER_BOUND));
    }

    /// @return p The price of the spot token in dollar coins.
    /// @return v True if the price is valid and can be used by downstream consumers.
    function perpPrice() external override returns (uint256, bool) {
        // NOTE: Since {DECIMALS} == {AMPL_CPI_ORACLE_DECIMALS} == 18
        // we don't adjust the returned values.
        (uint256 targetPrice, bool targetPriceValid) = AMPL_CPI_ORACLE.getData();
        uint256 p = targetPrice.mulDiv(SPOT.getTVL(), SPOT.totalSupply());
        bool v = (targetPriceValid && isSPOTHealthy());
        return (p, v);
    }

    /// @return Number of decimals representing a price of 1.0 USD.
    function decimals() external pure override returns (uint8) {
        return uint8(DECIMALS);
    }

    //-----------------------------------------------------------------------------
    // Public methods

    /// @return If the spot token is healthy.
    function isSPOTHealthy() public returns (bool) {
        // If the SPOT's `deviationRatio` is lower than the defined bound
        // i.e) it doesn't have enough capital to cover future rollovers,
        // we consider it unhealthy.
        uint256 spotDR = SPOT.deviationRatio().mulDiv(ONE, SPOT_DR_ONE);
        if (spotDR < minSPOTDR) {
            return false;
        }

        // We compute the CDR of all the senior tranches backing perp.
        // If any one of the seniors is mature or has a CDR below below the defined minimum,
        // we consider it unhealthy.
        // NOTE: Any CDR below 100%, means that the tranche is impaired
        // and is roughly equivalent to holding AMPL.
        uint8 reserveCount = uint8(SPOT.getReserveCount());
        for (uint8 i = 1; i < reserveCount; i++) {
            ITranche tranche = ITranche(address(SPOT.getReserveAt(i)));
            IBondController bond = IBondController(tranche.bond());
            if (bond.isMature()) {
                return false;
            }
            uint256 seniorCDR = AMPL.balanceOf(address(bond)).mulDiv(
                ONE,
                tranche.totalSupply()
            );
            if (seniorCDR < minSeniorCDR) {
                return false;
            }
        }

        // If SPOT has ANY raw AMPL as collateral, we consider it unhealthy.
        // NOTE: In practice some dust might exist or someone could grief this check
        // by transferring some dust AMPL into the spot contract.
        // We consider SPOT unhealthy if it has more than `AMPL_DUST_AMT` AMPL.
        if (AMPL.balanceOf(address(SPOT)) > AMPL_DUST_AMT) {
            return false;
        }

        return true;
    }

    //-----------------------------------------------------------------------------
    // Private methods

    /// @dev Fetches most recent report from the given chain link oracle contract.
    ///      The data is considered invalid if the latest report is stale.
    function _getCLOracleData(
        IChainlinkOracle oracle,
        uint256 oracleDecimals
    ) private view returns (uint256, bool) {
        (, int256 p, , uint256 updatedAt, ) = oracle.latestRoundData();
        uint256 price = uint256(p).mulDiv(ONE, 10 ** oracleDecimals);
        return (
            price,
            (block.timestamp - updatedAt) <= CL_ORACLE_STALENESS_THRESHOLD_SEC
        );
    }
}
