// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./UsingBaseOracle.sol";
import "./BaseOracleExt.sol";
import "../utils/BlueBerryErrors.sol" as Errors;
import "../libraries/UniV3/UniV3WrappedLibMockup.sol";
import "../interfaces/IBaseOracle.sol";
import "../interfaces/ichi/IICHIVault.sol";

/**
 * @author BlueberryProtocol
 * @title Ichi Vault Oracle
 * @notice Oracle contract provides price feeds of Ichi Vault tokens
 * @dev The logic of this oracle is using legacy & traditional mathematics of Uniswap V2 Lp Oracle.
 *      Base token prices are fetched from Chainlink or Band Protocol.
 *      To prevent flashloan price manipulations, it compares spot & twap prices from Uni V3 Pool.
 */
contract IchiVaultOracle is
    UsingBaseOracle,
    IBaseOracle,
    Ownable,
    BaseOracleExt
{
    mapping(address => uint256) public maxPriceDeviations;

    constructor(IBaseOracle _base) UsingBaseOracle(_base) {}

    event SetPriceDeviation(address indexed token, uint256 maxPriceDeviation);

    /// @notice Set price deviations for given token
    /// @dev Input token is the underlying token of ICHI Vaults which is token0 or token1 of Uni V3 Pool
    /// @param token Token to price deviation
    /// @param maxPriceDeviation Max price deviation (in 1e18) of price feeds
    function setPriceDeviation(
        address token,
        uint256 maxPriceDeviation
    ) external onlyOwner {
        // Validate inputs
        if (token == address(0)) revert Errors.ZERO_ADDRESS();
        if (maxPriceDeviation > Constants.MAX_PRICE_DEVIATION)
            revert Errors.OUT_OF_DEVIATION_CAP(maxPriceDeviation);

        maxPriceDeviations[token] = maxPriceDeviation;
        emit SetPriceDeviation(token, maxPriceDeviation);
    }

    /**
     * @notice Get token0 spot price quoted in token1
     * @dev Returns token0 price of 1e18 amount
     * @param vault ICHI Vault address
     * @return price spot price of token0 quoted in token1
     */
    function spotPrice0InToken1(
        IICHIVault vault
    ) public view returns (uint256) {
        return
            UniV3WrappedLibMockup.getQuoteAtTick(
                vault.currentTick(), // current tick
                uint128(Constants.PRICE_PRECISION), // amountIn
                vault.token0(), // tokenIn
                vault.token1() // tokenOut
            );
    }

    /**
     * @notice Get token0 twap price quoted in token1
     * @dev Returns token0 price of 1e18 amount
     * @param vault ICHI Vault address
     * @return price spot price of token0 quoted in token1
     */
    function twapPrice0InToken1(
        IICHIVault vault
    ) public view returns (uint256) {
        uint32 twapPeriod = vault.twapPeriod();
        if (twapPeriod > Constants.MAX_TIME_GAP)
            revert Errors.TOO_LONG_DELAY(twapPeriod);
        if (twapPeriod < Constants.MIN_TIME_GAP)
            revert Errors.TOO_LOW_MEAN(twapPeriod);
        (int24 twapTick, ) = UniV3WrappedLibMockup.consult(
            vault.pool(),
            twapPeriod
        );
        return
            UniV3WrappedLibMockup.getQuoteAtTick(
                twapTick,
                uint128(Constants.PRICE_PRECISION), // amountIn
                vault.token0(), // tokenIn
                vault.token1() // tokenOut
            );
    }

    /**
     * @notice Return vault token price in USD, with 18 decimals of precision.
     * @param token The vault token to get the price of.
     * @return price USD price of token in 18 decimal
     */
    function getPrice(address token) external view override returns (uint256) {
        IICHIVault vault = IICHIVault(token);
        uint256 totalSupply = vault.totalSupply();
        if (totalSupply == 0) return 0;

        address token0 = vault.token0();
        address token1 = vault.token1();

        // Check price manipulations on Uni V3 pool by flashloan attack
        uint256 spotPrice = spotPrice0InToken1(vault);
        uint256 twapPrice = twapPrice0InToken1(vault);
        uint256 maxPriceDeviation = maxPriceDeviations[token0];
        if (!_isValidPrices(spotPrice, twapPrice, maxPriceDeviation))
            revert Errors.EXCEED_DEVIATION();

        // Total reserve / total supply
        (uint256 r0, uint256 r1) = vault.getTotalAmounts();
        uint256 px0 = base.getPrice(address(token0));
        uint256 px1 = base.getPrice(address(token1));
        uint256 t0Decimal = IERC20Metadata(token0).decimals();
        uint256 t1Decimal = IERC20Metadata(token1).decimals();

        uint256 totalReserve = (r0 * px0) /
            10 ** t0Decimal +
            (r1 * px1) /
            10 ** t1Decimal;

        return (totalReserve * 10 ** vault.decimals()) / totalSupply;
    }
}
