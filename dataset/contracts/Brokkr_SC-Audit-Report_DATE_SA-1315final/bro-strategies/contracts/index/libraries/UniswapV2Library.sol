// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import { Errors } from "./Errors.sol";
import { IUniswapV2Pair } from "../dependencies/IUniswapV2Pair.sol";
import { IUniswapV2Router } from "../dependencies/IUniswapV2Router.sol";

library UniswapV2Library {
    function swapExactTokensForTokens(
        IUniswapV2Router router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        IERC20Upgradeable(path[0]).approve(address(router), amountIn);

        amountOut = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        )[path.length - 1];
    }

    function swapTokensForExactTokens(
        IUniswapV2Router router,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path
    ) internal returns (uint256 amountIn) {
        IERC20Upgradeable(path[0]).approve(address(router), amountInMax);

        amountIn = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        )[0];
    }

    function getAmountOut(
        IUniswapV2Router router,
        IUniswapV2Pair pair,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = _getReserveInAndOut(
            pair,
            tokenIn,
            tokenOut
        );

        amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        IUniswapV2Router router,
        IUniswapV2Pair pair,
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint256 amountIn) {
        (uint256 reserveIn, uint256 reserveOut) = _getReserveInAndOut(
            pair,
            tokenIn,
            tokenOut
        );

        amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function _getReserveInAndOut(
        IUniswapV2Pair pair,
        address tokenIn,
        address tokenOut
    ) private view returns (uint256 reserveIn, uint256 reserveOut) {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();

        (address token0, address token1) = (pair.token0(), pair.token1());

        if (tokenIn == token0 && tokenOut == token1) {
            (reserveIn, reserveOut) = (reserve0, reserve1);
        } else if (tokenIn == token1 && tokenOut == token0) {
            (reserveIn, reserveOut) = (reserve1, reserve0);
        } else {
            revert Errors.SwapAdapter_WrongPair(tokenIn, tokenOut);
        }
    }
}
