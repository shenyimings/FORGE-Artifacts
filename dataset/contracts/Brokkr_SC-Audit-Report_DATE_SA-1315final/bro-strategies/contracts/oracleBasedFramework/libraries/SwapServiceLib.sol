// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Math.sol";

import "./InvestableLib.sol";
import "../../dependencies/swap/IUniswapV2LikeRouter.sol";
import "../../dependencies/traderjoe/ITraderJoeLBRouter.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

error InvalidSwapServiceProvider();

enum SwapServiceProvider {
    TraderJoe,
    TraderJoeV2,
    UniswapV2,
    UniswapV3
}

struct SwapService {
    SwapServiceProvider provider;
    address router;
}

library SwapServiceLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ///////////////////////////////////////////
    // External library functions and wrappers
    //
    // Ext suffix: These entry points are for the externally deployed libraries, which in turn forward requests to the
    //             internal implementation of the swap function. Before forwarding it to the internal implementation,
    //             it also converts the raw byte array to typed values for example uint256[] in case of Uniswap V3.
    //
    // Wrapper suffix: allows smart contracts to call the externally SwapLibrary functions without the Library address
    //                 hardcoded into the contract
    ///////////////////////////////////////////

    function swapExactTokensForTokensExtWrapper(
        address swapLibAddress,
        SwapService memory swapService,
        uint256 amountIn,
        uint256 minAmountOut,
        address[] memory path,
        bytes memory data
    ) internal returns (uint256 amountOut) {
        bytes memory returnData = Address.functionDelegateCall(
            swapLibAddress,
            abi.encodeWithSignature(
                "swapExactTokensForTokensExt(SwapService,uint256,uint256,address[],bytes)",
                swapService,
                amountIn,
                minAmountOut,
                path,
                data
            )
        );
        amountOut = abi.decode(returnData, (uint256));
    }

    function swapExactTokensForTokensExt(
        SwapService calldata swapService,
        uint256 amountIn,
        uint256 minAmountOut,
        address[] calldata path,
        bytes calldata
    ) external returns (uint256 amountOut) {
        if (
            swapService.provider == SwapServiceProvider.TraderJoe ||
            swapService.provider == SwapServiceProvider.UniswapV2
        ) {
            amountOut = swapExactTokensForTokens(
                swapService,
                amountIn,
                minAmountOut,
                path,
                new uint256[](0)
            );
        } else {
            // converting bytes to the appropriate array for TraderJoeV2 and UniswapV3
            revert InvalidSwapServiceProvider();
        }
    }

    ///////////////////////////////////////////
    // Internal library functions
    ///////////////////////////////////////////

    function swapExactTokensForTokens(
        SwapService memory swapService,
        uint256 amountIn,
        uint256 minAmountOut,
        address[] memory path,
        uint256[] memory binSteps
    ) internal returns (uint256 amountOut) {
        if (
            swapService.provider == SwapServiceProvider.TraderJoe ||
            swapService.provider == SwapServiceProvider.UniswapV2
        ) {
            IUniswapV2LikeRouter uniswapV2LikeRouter = IUniswapV2LikeRouter(
                swapService.router
            );

            IERC20Upgradeable(path[0]).approve(
                address(uniswapV2LikeRouter),
                amountIn
            );
            amountOut = uniswapV2LikeRouter.swapExactTokensForTokens(
                amountIn,
                minAmountOut,
                path,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            )[path.length - 1];
        } else if (swapService.provider == SwapServiceProvider.TraderJoeV2) {
            ITraderJoeLBRouter traderjoeLBRouter = ITraderJoeLBRouter(
                swapService.router
            );

            IERC20Upgradeable(path[0]).approve(
                address(traderjoeLBRouter),
                amountIn
            );

            amountOut = traderjoeLBRouter.swapExactTokensForTokens(
                amountIn,
                minAmountOut,
                binSteps,
                path,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            );
        } else {
            revert InvalidSwapServiceProvider();
        }
    }

    function swapTokensForExactTokens(
        SwapService memory swapService,
        uint256 amountOut,
        uint256 maxAmountIn,
        address[] memory path,
        uint256[] memory binSteps
    ) internal returns (uint256 amountIn) {
        if (
            swapService.provider == SwapServiceProvider.TraderJoe ||
            swapService.provider == SwapServiceProvider.UniswapV2
        ) {
            IUniswapV2LikeRouter uniswapV2LikeRouter = IUniswapV2LikeRouter(
                swapService.router
            );

            uint256[] memory maxAmountInCalculated = uniswapV2LikeRouter
                .getAmountsIn(amountOut, path);

            uint256 maxAmountInFinal = Math.min(
                maxAmountInCalculated[0],
                maxAmountIn
            );
            IERC20Upgradeable(path[0]).approve(
                address(uniswapV2LikeRouter),
                Math.min(maxAmountInCalculated[0], maxAmountIn)
            );

            amountIn = uniswapV2LikeRouter.swapTokensForExactTokens(
                amountOut,
                maxAmountInFinal,
                path,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            )[0];
        } else if (swapService.provider == SwapServiceProvider.TraderJoeV2) {
            ITraderJoeLBRouter traderjoeLBRouter = ITraderJoeLBRouter(
                swapService.router
            );

            IERC20Upgradeable(path[0]).approve(
                address(traderjoeLBRouter),
                maxAmountIn
            );

            amountIn = traderjoeLBRouter.swapTokensForExactTokens(
                amountOut,
                maxAmountIn,
                binSteps,
                path,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            )[0];

            IERC20Upgradeable(path[0]).approve(address(traderjoeLBRouter), 0);
        } else {
            revert InvalidSwapServiceProvider();
        }
    }

    function swapExactTokensForNative(
        SwapService memory swapService,
        uint256 amountIn,
        uint256 minAmountOut,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        uint256 pathOldLength = path.length;
        address[] memory pathNew = new address[](pathOldLength + 1);
        for (uint256 i = 0; i < pathOldLength; ++i) {
            pathNew[i] = path[i];
        }
        if (swapService.provider == SwapServiceProvider.UniswapV2) {
            pathNew[pathOldLength] = address(InvestableLib.BINANCE_WBNB);
            IUniswapV2LikeRouter router = IUniswapV2LikeRouter(
                swapService.router
            );

            IERC20Upgradeable(pathNew[0]).approve(address(router), amountIn);

            amountOut = router.swapExactTokensForETH(
                amountIn,
                minAmountOut,
                pathNew,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            )[pathOldLength];
        } else {
            revert InvalidSwapServiceProvider();
        }
    }

    function swapExactNativeForTokens(
        SwapService memory swapService,
        uint256 amountIn,
        uint256 minAmountOut,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        uint256 pathOldLength = path.length;
        address[] memory pathNew = new address[](pathOldLength + 1);
        for (uint256 i = 1; i <= pathOldLength; ++i) {
            pathNew[i] = path[i - 1];
        }

        if (swapService.provider == SwapServiceProvider.UniswapV2) {
            pathNew[0] = address(InvestableLib.BINANCE_WBNB);
            IUniswapV2LikeRouter router = IUniswapV2LikeRouter(
                swapService.router
            );

            amountOut = router.swapExactETHForTokens{ value: amountIn }(
                minAmountOut,
                pathNew,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            )[pathOldLength];
        } else {
            revert InvalidSwapServiceProvider();
        }
    }

    function swapTokensForExactNative(
        SwapService memory swapService,
        uint256 amountOut,
        uint256 maxAmountIn,
        address[] memory path
    ) internal returns (uint256 amountIn) {
        uint256 pathOldLength = path.length;
        address[] memory pathNew = new address[](pathOldLength + 1);
        for (uint256 i = 0; i < pathOldLength; ++i) {
            pathNew[i] = path[i];
        }

        if (swapService.provider == SwapServiceProvider.UniswapV2) {
            pathNew[pathOldLength] = address(InvestableLib.BINANCE_WBNB);
            IUniswapV2LikeRouter router = IUniswapV2LikeRouter(
                swapService.router
            );

            uint256[] memory maxAmountInCalculated = router.getAmountsIn(
                amountOut,
                pathNew
            );

            uint256 maxAmountInFinal = Math.min(
                maxAmountInCalculated[0],
                maxAmountIn
            );
            IERC20Upgradeable(pathNew[0]).approve(
                address(router),
                maxAmountInFinal
            );

            amountIn = router.swapTokensForExactETH(
                amountOut,
                maxAmountInFinal,
                pathNew,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            )[0];
        } else {
            revert InvalidSwapServiceProvider();
        }
    }

    function getAmountsIn(
        SwapService memory swapService,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        if (
            swapService.provider == SwapServiceProvider.TraderJoe ||
            swapService.provider == SwapServiceProvider.UniswapV2
        ) {
            IUniswapV2LikeRouter uniswapV2LikeRouter = IUniswapV2LikeRouter(
                swapService.router
            );

            amounts = uniswapV2LikeRouter.getAmountsIn(amountOut, path);
        } else {
            revert InvalidSwapServiceProvider();
        }
    }

    function getAmountsOut(
        SwapService memory swapService,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        if (
            swapService.provider == SwapServiceProvider.TraderJoe ||
            swapService.provider == SwapServiceProvider.UniswapV2
        ) {
            IUniswapV2LikeRouter uniswapV2LikeRouter = IUniswapV2LikeRouter(
                swapService.router
            );

            amounts = uniswapV2LikeRouter.getAmountsOut(amountIn, path);
        } else {
            revert InvalidSwapServiceProvider();
        }
    }
}
