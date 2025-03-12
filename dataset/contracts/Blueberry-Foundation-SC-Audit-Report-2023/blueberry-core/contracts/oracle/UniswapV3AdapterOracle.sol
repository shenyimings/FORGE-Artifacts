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
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./BaseAdapter.sol";
import "./UsingBaseOracle.sol";
import "../interfaces/IBaseOracle.sol";
import "../libraries/UniV3/UniV3WrappedLibMockup.sol";

/**
 * @author BlueberryProtocol
 * @title Uniswap V3 Adapter Oracle
 * @notice Oracle contract which provides price feeds of tokens from Uni V3 pool paired with stablecoins
 */
contract UniswapV3AdapterOracle is IBaseOracle, UsingBaseOracle, BaseAdapter {
    using SafeCast for uint256;

    event SetPoolStable(address token, address pool);

    /// @dev Mapping from token address to Uni V3 pool of token/(USDT|USDC|DAI) pair
    mapping(address => address) public stablePools;

    constructor(IBaseOracle _base) UsingBaseOracle(_base) {}

    /// @notice Set stablecoin pools for multiple tokens
    /// @param tokens list of tokens to set stablecoin pool references
    /// @param pools list of reference pool addresses
    function setStablePools(
        address[] calldata tokens,
        address[] calldata pools
    ) external onlyOwner {
        if (tokens.length != pools.length) revert Errors.INPUT_ARRAY_MISMATCH();
        for (uint256 idx = 0; idx < tokens.length; idx++) {
            if (tokens[idx] == address(0) || pools[idx] == address(0))
                revert Errors.ZERO_ADDRESS();
            if (
                tokens[idx] != IUniswapV3Pool(pools[idx]).token0() &&
                tokens[idx] != IUniswapV3Pool(pools[idx]).token1()
            ) revert Errors.NO_STABLEPOOL(pools[idx]);
            stablePools[tokens[idx]] = pools[idx];
            emit SetPoolStable(tokens[idx], pools[idx]);
        }
    }

    /// @notice Return USD price of given token, multiplied by 10**18.
    /// @param token The vault token to get the price of.
    /// @return price USD price of token in 18 decimals.
    function getPrice(address token) external view override returns (uint256) {
        // Maximum cap of timeGap is 2 days(172,800), safe to convert
        uint32 secondsAgo = timeGaps[token].toUint32();
        if (secondsAgo == 0) revert Errors.NO_MEAN(token);

        address stablePool = stablePools[token];
        if (stablePool == address(0)) revert Errors.NO_STABLEPOOL(token);

        address poolToken0 = IUniswapV3Pool(stablePool).token0();
        address poolToken1 = IUniswapV3Pool(stablePool).token1();
        address stablecoin = poolToken0 == token ? poolToken1 : poolToken0; // get stable token address

        uint8 stableDecimals = IERC20Metadata(stablecoin).decimals();
        uint8 tokenDecimals = IERC20Metadata(token).decimals();

        (int24 arithmeticMeanTick, ) = UniV3WrappedLibMockup.consult(
            stablePool,
            secondsAgo
        );
        uint256 quoteTokenAmountForStable = UniV3WrappedLibMockup
            .getQuoteAtTick(
                arithmeticMeanTick,
                uint256(10 ** tokenDecimals).toUint128(),
                token,
                stablecoin
            );

        return
            (quoteTokenAmountForStable * base.getPrice(stablecoin)) /
            10 ** stableDecimals;
    }
}
