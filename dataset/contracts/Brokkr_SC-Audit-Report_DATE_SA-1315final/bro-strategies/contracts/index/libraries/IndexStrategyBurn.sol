// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Errors } from "../libraries/Errors.sol";
import { BurnParams } from "../Common.sol";
import { IndexStrategyUtils } from "./IndexStrategyUtils.sol";
import { SwapAdapter } from "../libraries/SwapAdapter.sol";
import { Constants } from "../libraries/Constants.sol";
import { INATIVE } from "../dependencies/INATIVE.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

library IndexStrategyBurn {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct BurnExactIndexForTokenLocals {
        address bestRouter;
        uint256 amountTokenOut;
        uint256 amountWNATIVE;
    }

    /**
     * @dev Burns index tokens in exchange for a specified token.
     * @param burnParams The burn parameters that species the burning details.
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param weights The datastructure describing component weights.
     * @param routers The datastructure describing routers (used for swapping).
     * @return amountToken The amount of tokens received.
     */
    function burnExactIndexForToken(
        BurnParams memory burnParams,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => uint256) storage weights,
        mapping(address => address[]) storage routers
    ) external returns (uint256 amountToken) {
        BurnExactIndexForTokenLocals memory burnExactIndexForTokenLocals;

        if (burnParams.recipient == address(0)) {
            revert Errors.Index_ZeroAddress();
        }

        burnExactIndexForTokenLocals.amountWNATIVE = burnExactIndexForWNATIVE(
            burnParams,
            pairData,
            dexs,
            weights,
            routers
        );

        (
            burnExactIndexForTokenLocals.amountTokenOut,
            burnExactIndexForTokenLocals.bestRouter
        ) = IndexStrategyUtils.getAmountOutMax(
            routers[burnParams.token],
            burnExactIndexForTokenLocals.amountWNATIVE,
            burnParams.wNATIVE,
            burnParams.token,
            dexs,
            pairData
        );

        amountToken = IndexStrategyUtils.swapExactTokenForToken(
            burnExactIndexForTokenLocals.bestRouter,
            burnExactIndexForTokenLocals.amountWNATIVE,
            burnExactIndexForTokenLocals.amountTokenOut,
            burnParams.wNATIVE,
            burnParams.token,
            dexs,
            pairData
        );

        if (amountToken != burnExactIndexForTokenLocals.amountTokenOut) {
            revert Errors.Index_WrongSwapAmount();
        }

        if (amountToken < burnParams.amountTokenMin) {
            revert Errors.Index_BelowMinAmount();
        }

        IERC20Upgradeable(burnParams.token).safeTransfer(
            burnParams.recipient,
            amountToken
        );
    }

    /**
     * @dev Burns index tokens in exchange for the native asset (such as Ether).
     * @param burnParams The burn parameters that species the burning details.
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param weights The datastructure describing component weights.
     * @param routers The datastructure describing routers (used for swapping).
     * @return amountNATIVE The amount of native tokens received.
     */
    function burnExactIndexForNATIVE(
        BurnParams memory burnParams,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => uint256) storage weights,
        mapping(address => address[]) storage routers
    ) external returns (uint256 amountNATIVE) {
        if (burnParams.recipient == address(0)) {
            revert Errors.Index_ZeroAddress();
        }

        amountNATIVE = burnExactIndexForWNATIVE(
            burnParams,
            pairData,
            dexs,
            weights,
            routers
        );

        if (amountNATIVE < burnParams.amountTokenMin) {
            revert Errors.Index_BelowMinAmount();
        }

        INATIVE(burnParams.wNATIVE).withdraw(amountNATIVE);

        payable(burnParams.recipient).transfer(amountNATIVE);
    }

    struct BurnExactIndexForWNATIVELocals {
        uint256 amountComponent;
        uint256 amountWNATIVEOut;
        address bestRouter;
    }

    /**
     * @dev Burns the exact index amount of the index token and swaps components for wNATIVE.
     * @param burnParams The burn parameters that species the burning details.
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param weights The datastructure describing component weights.
     * @param routers The datastructure describing routers (used for swapping).
     * @return amountWNATIVE The amount of wNATIVE received from burning the index tokens.
     */
    function burnExactIndexForWNATIVE(
        BurnParams memory burnParams,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => uint256) storage weights,
        mapping(address => address[]) storage routers
    ) internal returns (uint256 amountWNATIVE) {
        BurnExactIndexForWNATIVELocals memory burnExactIndexForWNATIVELocals;

        for (uint256 i = 0; i < burnParams.components.length; i++) {
            if (weights[burnParams.components[i]] == 0) {
                continue;
            }

            burnExactIndexForWNATIVELocals.amountComponent =
                (burnParams.amountIndex * weights[burnParams.components[i]]) /
                Constants.PRECISION;

            (
                burnExactIndexForWNATIVELocals.amountWNATIVEOut,
                burnExactIndexForWNATIVELocals.bestRouter
            ) = IndexStrategyUtils.getAmountOutMax(
                routers[burnParams.components[i]],
                burnExactIndexForWNATIVELocals.amountComponent,
                burnParams.components[i],
                burnParams.wNATIVE,
                dexs,
                pairData
            );

            if (burnExactIndexForWNATIVELocals.amountWNATIVEOut == 0) {
                continue;
            }

            amountWNATIVE += IndexStrategyUtils.swapExactTokenForToken(
                burnExactIndexForWNATIVELocals.bestRouter,
                burnExactIndexForWNATIVELocals.amountComponent,
                burnExactIndexForWNATIVELocals.amountWNATIVEOut,
                burnParams.components[i],
                burnParams.wNATIVE,
                dexs,
                pairData
            );
        }

        burnParams.indexToken.burnFrom(
            burnParams.msgSender,
            burnParams.amountIndex
        );
    }
}
