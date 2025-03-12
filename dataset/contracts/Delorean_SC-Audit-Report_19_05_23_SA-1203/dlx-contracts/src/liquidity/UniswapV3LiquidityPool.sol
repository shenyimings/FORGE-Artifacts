// SPDX-License-Identifier: BSL
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ILiquidityPool } from "../interfaces/ILiquidityPool.sol";
import { ISwapRouter } from "../interfaces/uniswap/ISwapRouter.sol";
import { IQuoterV2 } from "../interfaces/uniswap/IQuoterV2.sol";
import { IUniswapV3Pool } from "../interfaces/uniswap/IUniswapV3Pool.sol";

/// @notice Wrapped interface to a Uniswap V3 liquidity pool.
contract UniswapV3LiquidityPool is ILiquidityPool {
    using SafeERC20 for IERC20;

    uint24 public immutable fee;

    IUniswapV3Pool public immutable pool;
    ISwapRouter public immutable router;
    IQuoterV2 public immutable quoter;

    modifier validAddress(address who) {
        require(who != address(0), "ULP: zero address");
        require(who != address(this), "ULP: this address");
        _;
    }

    /// @notice Create a UniswapV3LiquidityPool.
    /// @param pool_ The Uniswap pool.
    /// @param router_ The Uniswap swap router.
    /// @param quoter_ The Uniswap swap quoter.
    constructor(address pool_,
                address router_,
                address quoter_) {

        require(pool_ != address(0), "zero address");
        require(router_ != address(0), "zero address");
        require(quoter_ != address(0), "zero address");

        pool = IUniswapV3Pool(pool_);
        router = ISwapRouter(router_);
        quoter = IQuoterV2(quoter_);

        token0 = pool.token0();
        token1 = pool.token1();
        fee = pool.fee();
    }

    /// @notice Compute the result of a swap.
    /// @dev Not a view, and should not be used on-chain, due to underlying Uniswap v3 behavior.
    /// @param tokenIn Token which is being input.
    /// @param amountIn Amount of the token being input.
    /// @param sqrtPriceLimitX96 Price limit in sqrtX96 format.
    /// @return Amount of the other token output.
    /// @return New price after the swap.
    function previewSwap(address tokenIn, uint128 amountIn, uint128 sqrtPriceLimitX96)
        external override returns (uint256, uint256) {

        IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2.QuoteExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenIn == token0 ? token1 : token0,
            amountIn: amountIn,
            fee: fee,
            sqrtPriceLimitX96: sqrtPriceLimitX96 });

        (uint256 amountOut, uint160 sqrtPriceX96After, ,) = quoter.quoteExactInputSingle(params);

        return (amountOut, uint256(sqrtPriceX96After));
    }

    /// @notice Compute the result of a swap, with exact output.
    /// @dev Not a view, and should not be used on-chain, due to underlying Uniswap v3 behavior.
    /// @param tokenIn Token which is being input.
    /// @param amountOut Amount of the other token output.
    /// @param sqrtPriceLimitX96 Price limit in sqrtX96 format.
    /// @return Amount of the token input.
    /// @return New price after the swap.
    function previewSwapOut(address tokenIn, uint128 amountOut, uint128 sqrtPriceLimitX96)
        external override returns (uint256, uint256) {
        IQuoterV2.QuoteExactOutputSingleParams memory params = IQuoterV2.QuoteExactOutputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenIn == token0 ? token1 : token0,
            amount: amountOut,
            fee: fee,
            sqrtPriceLimitX96: sqrtPriceLimitX96 });

        (uint256 amountIn, uint160 sqrtPriceX96After, ,) = quoter.quoteExactOutputSingle(params);
        return (amountIn, uint256(sqrtPriceX96After));
    }

    /// @notice Perform a swap.
    /// @param tokenIn Token which is being input.
    /// @param amountIn Amount of the token being input.
    /// @param amountOutMinimum Required minimum amount of the other token output.
    /// @param sqrtPriceLimitX96 Price limit in sqrtX96 format.
    /// @return Actual amount of the other token output.
    function swap(address recipient,
                  address tokenIn,
                  uint128 amountIn,
                  uint128 amountOutMinimum,
                  uint128 sqrtPriceLimitX96)
        external
        validAddress(recipient)
        override
        returns (uint256) {

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).safeApprove(address(router), 0);
        IERC20(tokenIn).safeApprove(address(router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenIn == token0 ? token1 : token0,
                fee: fee,
                recipient: recipient,
                deadline: block.timestamp + 10,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: sqrtPriceLimitX96 });

        uint256 amountOut = router.exactInputSingle(params);

        return amountOut;
    }
}
