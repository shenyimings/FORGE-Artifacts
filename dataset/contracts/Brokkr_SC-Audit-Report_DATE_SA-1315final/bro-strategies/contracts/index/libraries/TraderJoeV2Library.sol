// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import { ITraderJoeV2Pair } from "../dependencies/ITraderJoeV2Pair.sol";
import { ITraderJoeV2Router } from "../dependencies/ITraderJoeV2Router.sol";

library TraderJoeV2Library {
    function swapExactTokensForTokens(
        ITraderJoeV2Router router,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256[] memory binSteps,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        IERC20Upgradeable(path[0]).approve(address(router), amountIn);

        amountOut = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            binSteps,
            path,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        );
    }

    function swapTokensForExactTokens(
        ITraderJoeV2Router router,
        uint256 amountOut,
        uint256 amountInMax,
        uint256[] memory binSteps,
        address[] memory path
    ) internal returns (uint256 amountIn) {
        IERC20Upgradeable(path[0]).approve(address(router), amountInMax);

        amountIn = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            binSteps,
            path,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        )[0];
    }

    function getAmountOut(
        ITraderJoeV2Router router,
        ITraderJoeV2Pair pair,
        uint256 amountIn,
        address,
        address tokenOut
    ) internal view returns (uint256 amountOut) {
        (amountOut, ) = router.getSwapOut(
            address(pair),
            amountIn,
            tokenOut == address(pair.tokenY())
        );
    }

    function getAmountIn(
        ITraderJoeV2Router router,
        ITraderJoeV2Pair pair,
        uint256 amountOut,
        address,
        address tokenOut
    ) internal view returns (uint256 amountIn) {
        (amountIn, ) = router.getSwapIn(
            address(pair),
            amountOut,
            tokenOut == address(pair.tokenY())
        );
    }
}
