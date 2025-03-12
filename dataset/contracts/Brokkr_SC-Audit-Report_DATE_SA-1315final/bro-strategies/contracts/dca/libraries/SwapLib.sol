// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IUniswapV2LikeRouter } from "../../dependencies/swap/IUniswapV2LikeRouter.sol";
import { ITraderJoeLBRouter } from "../../dependencies/traderjoe/ITraderJoeLBRouter.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

library SwapLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    enum Dex {
        UniswapV2,
        TraderJoeV2,
        TraderJoeV2dot1,
        UniswapV3,
        Camelot
    }

    struct Router {
        Dex dex;
        address router;
    }

    function swapTokensForTokens(
        Router memory router,
        uint256 amountIn,
        address[] memory path,
        uint256[] memory binSteps
    ) internal returns (uint256 amountOut) {
        IERC20Upgradeable(path[0]).safeIncreaseAllowance(
            router.router,
            amountIn
        );

        if (router.dex == Dex.UniswapV2) {
            IUniswapV2LikeRouter routerUniswapV2Like = IUniswapV2LikeRouter(
                router.router
            );

            amountOut = routerUniswapV2Like.swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp
            )[path.length - 1];
        } else if (router.dex == Dex.UniswapV3) {
            ISwapRouter routerUniswapV3 = ISwapRouter(router.router);

            amountOut = routerUniswapV3.exactInput(
                ISwapRouter.ExactInputParams({
                    path: createSwapPath(path, binSteps),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0
                })
            );
        } else if (router.dex == Dex.TraderJoeV2) {
            ITraderJoeLBRouter traderjoeLBRouter = ITraderJoeLBRouter(
                router.router
            );

            amountOut = traderjoeLBRouter.swapExactTokensForTokens(
                amountIn,
                0,
                binSteps,
                path,
                address(this),
                block.timestamp
            );
        } else {
            // solhint-disable-next-line reason-string
            revert("SwapLib: Invalid swap service provider");
        }
    }

    function createSwapPath(address[] memory path, uint256[] memory fees)
        private
        pure
        returns (bytes memory pathEncoded)
    {
        pathEncoded = abi.encodePacked(path[0]);
        for (uint256 i = 0; i < fees.length; i++) {
            uint24 fee = uint24(fees[i]);
            pathEncoded = abi.encodePacked(pathEncoded, fee, path[i + 1]);
        }
    }

    function getAmountOut(
        Router memory router,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256) {
        if (router.dex == Dex.UniswapV2) {
            return
                IUniswapV2LikeRouter(router.router).getAmountsOut(
                    amountIn,
                    path
                )[path.length - 1];
        } else {
            // solhint-disable-next-line reason-string
            revert("SwapLib: Invalid swap service provider");
        }
    }
}
