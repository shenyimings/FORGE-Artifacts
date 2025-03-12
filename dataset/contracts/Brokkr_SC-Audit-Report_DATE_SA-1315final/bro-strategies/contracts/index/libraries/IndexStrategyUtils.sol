// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Errors } from "../libraries/Errors.sol";
import { SwapAdapter } from "../libraries/SwapAdapter.sol";

library IndexStrategyUtils {
    using SwapAdapter for SwapAdapter.Setup;

    /**
     * @dev Calculates the maximum amount of `tokenOut` tokens that can be received for a given `amountIn` of `tokenIn` tokens,
     *      and identifies the best router to use for the swap among a list of routers.
     * @param routers The list of router addresses to consider for the swap.
     * @param amountIn The amount of `tokenIn` tokens.
     * @param tokenIn The address of the token to be swapped.
     * @param tokenOut The address of the token to receive.
     * @return amountOutMax The maximum amount of `tokenOut` tokens that can be received for the given `amountIn`.
     * @return bestRouter The address of the best router to use for the swap.
     */
    function getAmountOutMax(
        address[] memory routers,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData
    ) external returns (uint256 amountOutMax, address bestRouter) {
        if (tokenIn == tokenOut) {
            return (amountIn, address(0));
        }

        if (routers.length == 0) {
            revert Errors.Index_WrongPair(tokenIn, tokenOut);
        }

        amountOutMax = type(uint256).min;

        for (uint256 i = 0; i < routers.length; i++) {
            address router = routers[i];

            uint256 amountOut = SwapAdapter
                .Setup(
                    dexs[router],
                    router,
                    pairData[router][tokenIn][tokenOut]
                )
                .getAmountOut(amountIn, tokenIn, tokenOut);

            if (amountOut > amountOutMax) {
                amountOutMax = amountOut;
                bestRouter = router;
            }
        }
    }

    /**
     * @dev Calculates the maximum amount of `tokenOut` tokens that can be received for a given `amountIn` of `tokenIn` tokens,
     *      and identifies the best router to use for the swap among a list of routers.
     * @param routers The list of router addresses to consider for the swap.
     * @param amountIn The amount of `tokenIn` tokens.
     * @param tokenIn The address of the token to be swapped.
     * @param tokenOut The address of the token to receive.
     * @return amountOutMax The maximum amount of `tokenOut` tokens that can be received for the given `amountIn`.
     * @return bestRouter The address of the best router to use for the swap.
     */
    function getAmountOutMaxView(
        address[] memory routers,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData
    ) external view returns (uint256 amountOutMax, address bestRouter) {
        if (tokenIn == tokenOut) {
            return (amountIn, address(0));
        }

        if (routers.length == 0) {
            revert Errors.Index_WrongPair(tokenIn, tokenOut);
        }

        amountOutMax = type(uint256).min;

        for (uint256 i = 0; i < routers.length; i++) {
            address router = routers[i];

            // UniswapV3 estimation functions are not view, so skipping them
            if (dexs[router] == SwapAdapter.DEX.UniswapV3) continue;

            uint256 amountOut = SwapAdapter
                .Setup(
                    dexs[router],
                    router,
                    pairData[router][tokenIn][tokenOut]
                )
                .getAmountOutView(amountIn, tokenIn, tokenOut);

            if (amountOut > amountOutMax) {
                amountOutMax = amountOut;
                bestRouter = router;
            }
        }
    }

    /**
     * @dev Calculates the minimum amount of `tokenIn` tokens required to receive a given `amountOut` of `tokenOut` tokens,
     *      and identifies the best router to use for the swap among a list of routers.
     * @param routers The list of router addresses to consider for the swap.
     * @param amountOut The amount of `tokenOut` tokens to receive.
     * @param tokenIn The address of the token to be swapped.
     * @param tokenOut The address of the token to receive.
     * @return amountInMin The minimum amount of `tokenIn` tokens required to receive the given `amountOut`.
     * @return bestRouter The address of the best router to use for the swap.
     */
    function getAmountInMin(
        address[] memory routers,
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData
    ) external returns (uint256 amountInMin, address bestRouter) {
        if (tokenIn == tokenOut) {
            return (amountOut, address(0));
        }

        if (routers.length == 0) {
            revert Errors.Index_WrongPair(tokenIn, tokenOut);
        }

        amountInMin = type(uint256).max;

        for (uint256 i = 0; i < routers.length; i++) {
            address router = routers[i];

            uint256 amountIn = SwapAdapter
                .Setup(
                    dexs[router],
                    router,
                    pairData[router][tokenIn][tokenOut]
                )
                .getAmountIn(amountOut, tokenIn, tokenOut);

            if (amountIn < amountInMin) {
                amountInMin = amountIn;
                bestRouter = router;
            }
        }
    }

    /**
     * @dev Swaps a specific amount of `tokenIn` for an exact amount of `tokenOut` using a specified router.
     * @param router The address of the router contract to use for the swap.
     * @param amountOut The exact amount of `tokenOut` tokens to receive.
     * @param amountInMax The maximum amount of `tokenIn` tokens to be used for the swap.
     * @param tokenIn The address of the token to be swapped.
     * @param tokenOut The address of the token to receive.
     * @return amountIn The actual amount of `tokenIn` tokens used for the swap.
     */
    function swapTokenForExactToken(
        address router,
        uint256 amountOut,
        uint256 amountInMax,
        address tokenIn,
        address tokenOut,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData
    ) external returns (uint256 amountIn) {
        if (tokenIn == tokenOut) {
            return amountOut;
        }

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        amountIn = SwapAdapter
            .Setup(dexs[router], router, pairData[router][tokenIn][tokenOut])
            .swapTokensForExactTokens(amountOut, amountInMax, path);
    }

    /**
     * @dev Swaps exact token for token using a specific router.
     * @param router The router address to use for swapping.
     * @param amountIn The exact amount of input tokens.
     * @param amountOutMin The minimum amount of output tokens to receive.
     * @param tokenIn The input token address.
     * @param tokenOut The output token address.
     * @return amountOut The amount of output tokens received.
     */
    function swapExactTokenForToken(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData
    ) external returns (uint256 amountOut) {
        if (tokenIn == tokenOut) {
            return amountIn;
        }

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        amountOut = SwapAdapter
            .Setup(dexs[router], router, pairData[router][tokenIn][tokenOut])
            .swapExactTokensForTokens(amountIn, amountOutMin, path);
    }
}
