// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import { ITraderJoeV2Point1Pair } from "../dependencies/ITraderJoeV2Point1Pair.sol";
import { ITraderJoeV2Point1Router } from "../dependencies/ITraderJoeV2Point1Router.sol";

library TraderJoeV2Point1Library {
    function swapExactTokensForTokens(
        ITraderJoeV2Point1Router router,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256[] memory binSteps,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        IERC20Upgradeable(path[0]).approve(address(router), amountIn);

        ITraderJoeV2Point1Router.Version[]
            memory versions = new ITraderJoeV2Point1Router.Version[](
                binSteps.length
            );

        for (uint256 i = 0; i < versions.length; i++) {
            versions[i] = ITraderJoeV2Point1Router.Version.V2_1;
        }

        amountOut = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            ITraderJoeV2Point1Router.Path(binSteps, versions, path),
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        );
    }

    function swapTokensForExactTokens(
        ITraderJoeV2Point1Router router,
        uint256 amountOut,
        uint256 amountInMax,
        uint256[] memory binSteps,
        address[] memory path
    ) internal returns (uint256 amountIn) {
        IERC20Upgradeable(path[0]).approve(address(router), amountInMax);

        ITraderJoeV2Point1Router.Version[]
            memory versions = new ITraderJoeV2Point1Router.Version[](
                binSteps.length
            );

        for (uint256 i = 0; i < versions.length; i++) {
            versions[i] = ITraderJoeV2Point1Router.Version.V2_1;
        }

        amountIn = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            ITraderJoeV2Point1Router.Path(binSteps, versions, path),
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        )[0];
    }

    function getAmountOut(
        ITraderJoeV2Point1Router router,
        ITraderJoeV2Point1Pair pair,
        uint256 amountIn,
        address,
        address tokenOut
    ) internal view returns (uint256 amountOut) {
        (, amountOut, ) = router.getSwapOut(
            address(pair),
            uint128(amountIn),
            tokenOut == address(pair.getTokenY())
        );
    }

    function getAmountIn(
        ITraderJoeV2Point1Router router,
        ITraderJoeV2Point1Pair pair,
        uint256 amountOut,
        address,
        address tokenOut
    ) internal view returns (uint256 amountIn) {
        (amountIn, , ) = router.getSwapIn(
            address(pair),
            uint128(amountOut),
            tokenOut == address(pair.getTokenY())
        );
    }
}
