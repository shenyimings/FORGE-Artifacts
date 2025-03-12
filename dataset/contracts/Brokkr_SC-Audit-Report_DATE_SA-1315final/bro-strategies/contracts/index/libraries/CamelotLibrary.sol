// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import { Errors } from "./Errors.sol";
import { ICamelotPair } from "../dependencies/ICamelotPair.sol";
import { ICamelotRouter } from "../dependencies/ICamelotRouter.sol";

library CamelotLibrary {
    function swapExactTokensForTokens(
        ICamelotRouter router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        IERC20Upgradeable(path[0]).approve(address(router), amountIn);

        uint256 tokenOutBalanceBefore = IERC20Upgradeable(path[path.length - 1])
            .balanceOf(address(this));

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            address(0),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        );

        uint256 tokenOutBalanceAfter = IERC20Upgradeable(path[path.length - 1])
            .balanceOf(address(this));

        amountOut = tokenOutBalanceAfter - tokenOutBalanceBefore;
    }

    function swapTokensForExactTokens(
        ICamelotRouter router,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path
    ) internal returns (uint256 amountIn) {
        IERC20Upgradeable(path[0]).approve(address(router), amountInMax);

        uint256 tokenOutBalanceBefore = IERC20Upgradeable(path[path.length - 1])
            .balanceOf(address(this));

        // Note: In current algorithm, `swapTokensForExactTokens` is called
        // only when `amountInMax` equals to actual amount in. Under this assumption,
        // `swapExactTokensForTokens` is used instead of `swapTokensForExactTokens`
        // because Solidly forks doesn't support `swapTokensForExactTokens`.
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountInMax,
            amountOut,
            path,
            address(this),
            address(0),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        );

        uint256 tokenOutBalanceAfter = IERC20Upgradeable(path[path.length - 1])
            .balanceOf(address(this));

        uint256 amountOutReceived = tokenOutBalanceAfter -
            tokenOutBalanceBefore;

        if (amountOutReceived < amountOut) {
            revert Errors.Index_WrongSwapAmount();
        }

        amountIn = amountInMax;
    }

    function getAmountOut(
        ICamelotRouter,
        ICamelotPair pair,
        uint256 amountIn,
        address tokenIn
    ) internal view returns (uint256 amountOut) {
        amountOut = pair.getAmountOut(amountIn, tokenIn);
    }

    function getAmountIn(
        ICamelotRouter,
        ICamelotPair pair,
        uint256 amountOut,
        address tokenOut
    ) internal view returns (uint256 amountIn) {
        bool isStable = pair.stableSwap();

        if (isStable) {
            revert Errors.Index_SolidlyStableSwapNotSupported();
        }

        (
            uint112 reserve0,
            uint112 reserve1,
            uint16 token0FeePercent,
            uint16 token1FeePercent
        ) = pair.getReserves();

        address token1 = pair.token1();

        (uint112 reserveIn, uint112 reserveOut) = (tokenOut == token1)
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        uint16 feePercent = (tokenOut == token1)
            ? token0FeePercent
            : token1FeePercent;

        amountIn =
            (reserveIn * amountOut * 100000) /
            (reserveOut - amountOut) /
            (100000 - feePercent) +
            1;
    }
}
