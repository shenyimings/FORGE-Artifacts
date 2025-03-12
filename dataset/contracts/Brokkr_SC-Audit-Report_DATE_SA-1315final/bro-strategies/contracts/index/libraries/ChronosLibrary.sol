// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import { Errors } from "./Errors.sol";
import { IChronosFactory } from "../dependencies/IChronosFactory.sol";
import { IChronosPair } from "../dependencies/IChronosPair.sol";
import { IChronosRouter } from "../dependencies/IChronosRouter.sol";

library ChronosLibrary {
    function swapExactTokensForTokens(
        IChronosRouter router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        IERC20Upgradeable(path[0]).approve(address(router), amountIn);

        IChronosRouter.Route[] memory routes = new IChronosRouter.Route[](1);
        routes[0] = IChronosRouter.Route(path[0], path[path.length - 1], false);

        amountOut = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            routes,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        )[path.length - 1];
    }

    function swapTokensForExactTokens(
        IChronosRouter router,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path
    ) internal returns (uint256 amountIn) {
        IERC20Upgradeable(path[0]).approve(address(router), amountInMax);

        // Note: In current algorithm, `swapTokensForExactTokens` is called
        // only when `amountInMax` equals to actual amount in. Under this assumption,
        // `swapExactTokensForTokens` is used instead of `swapTokensForExactTokens`
        // because Solidly forks doesn't support `swapTokensForExactTokens`.
        IChronosRouter.Route[] memory routes = new IChronosRouter.Route[](1);
        routes[0] = IChronosRouter.Route(path[0], path[path.length - 1], false);

        uint256 amountOutReceived = router.swapExactTokensForTokens(
            amountInMax,
            amountOut,
            routes,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        )[path.length - 1];

        if (amountOutReceived < amountOut) {
            revert Errors.Index_WrongSwapAmount();
        }

        amountIn = amountInMax;
    }

    function getAmountOut(
        IChronosRouter,
        IChronosPair pair,
        uint256 amountIn,
        address tokenIn
    ) internal view returns (uint256 amountOut) {
        amountOut = pair.getAmountOut(amountIn, tokenIn);
    }

    function getAmountIn(
        IChronosRouter,
        IChronosPair pair,
        IChronosFactory factory,
        uint256 amountOut,
        address tokenOut
    ) internal view returns (uint256 amountIn) {
        bool isStable = pair.isStable();

        if (isStable) {
            revert Errors.Index_SolidlyStableSwapNotSupported();
        }

        uint256 fee = factory.getFee(isStable);

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();

        address token1 = pair.token1();

        (uint256 reserveIn, uint256 reserveOut) = (tokenOut == token1)
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        amountIn =
            (reserveIn * amountOut * 10000) /
            (reserveOut - amountOut) /
            (10000 - fee) +
            1;
    }
}
