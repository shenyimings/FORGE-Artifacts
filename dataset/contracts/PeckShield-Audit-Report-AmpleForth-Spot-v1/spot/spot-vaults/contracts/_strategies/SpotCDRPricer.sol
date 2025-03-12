// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPerpetualTranche } from "@ampleforthorg/spot-contracts/contracts/_interfaces/IPerpetualTranche.sol";
import { IChainlinkOracle } from "../_interfaces/external/IChainlinkOracle.sol";
import { IAmpleforthOracle } from "../_interfaces/external/IAmpleforthOracle.sol";
import { ISpotPricingStrategy } from "../_interfaces/ISpotPricingStrategy.sol";

/**
 * @title SpotCDRPricer
 *
 * @notice Pricing strategy adapter for SPOT.
 *
 *         SPOT is a perpetual claim on AMPL senior tranches.
 *         We price spot based on the redeemable value of it's collateral at maturity.
 *         NOTE: SPOT's internal `getTVL` prices the collateral this way.
 *
 *         SPOT_PRICE = (spot.getTVL() / spot.totalSupply()) * AMPL_TARGET
 *
 *         We get the AMPL target price from Ampleforth's CPI oracle,
 *         which is also used by the protocol to adjust AMPL supply through rebasing.
 *
 */
contract SpotCDRPricer is ISpotPricingStrategy {
    //-------------------------------------------------------------------------
    // Libraries
    using Math for uint256;

    //-------------------------------------------------------------------------
    // Constants & Immutables

    uint256 private constant DECIMALS = 18;
    uint256 private constant ONE = (10 ** DECIMALS);
    uint256 public constant CL_ORACLE_DECIMALS = 8;
    uint256 public constant CL_ORACLE_STALENESS_THRESHOLD_SEC = 3600 * 48; // 2 days
    uint256 public constant USD_UPPER_BOUND = (101 * ONE) / 100; // 1.01$
    uint256 public constant USD_LOWER_BOUND = (99 * ONE) / 100; // 0.99$

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
    ) {
        SPOT = spot;
        AMPL = IERC20(address(spot.underlying()));

        USD_ORACLE = usdOracle;
        USD_ORACLE_DECIMALS = usdOracle.decimals();

        AMPL_CPI_ORACLE = cpiOracle;
        AMPL_CPI_ORACLE_DECIMALS = cpiOracle.DECIMALS();
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
        return (p, targetPriceValid);
    }

    /// @return Number of decimals representing a price of 1.0 USD.
    function decimals() external pure override returns (uint8) {
        return uint8(DECIMALS);
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
