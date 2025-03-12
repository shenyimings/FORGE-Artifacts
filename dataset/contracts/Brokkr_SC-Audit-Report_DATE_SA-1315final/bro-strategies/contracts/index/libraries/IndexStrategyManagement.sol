// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Errors } from "../libraries/Errors.sol";
import { ManagementParams } from "../Common.sol";
import { IndexStrategyUtils } from "./IndexStrategyUtils.sol";
import { SwapAdapter } from "../libraries/SwapAdapter.sol";
import { Constants } from "../libraries/Constants.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

library IndexStrategyManagement {
    struct RebalanceLocals {
        address bestRouter;
        uint256 amountComponentOut;
        uint256 amountWNATIVEOut;
        uint256 amountWNATIVETotal;
        uint256[] requiredWNATIVEs;
        uint256 requiredWNATIVETotal;
        uint256 amountComponent;
        uint256 amountWNATIVE;
    }

    /**
     * @dev Rebalances the index strategy by adjusting the weights of the components.
     * @param managementParams The management parameters that species the minting details.
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param weights The datastructure describing component weights.
     * @param routers The datastructure describing routers (used for swapping).
     */
    function rebalance(
        ManagementParams memory managementParams,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => uint256) storage weights,
        mapping(address => address[]) storage routers
    ) external {
        RebalanceLocals memory rebalanceLocals;

        if (
            managementParams.components.length !=
            managementParams.targetWeights.length
        ) {
            revert Errors.Index_WrongTargetWeightsLength();
        }

        rebalanceLocals.requiredWNATIVEs = new uint256[](
            managementParams.components.length
        );

        uint256 indexTotalSupply = managementParams.indexToken.totalSupply();

        for (uint256 i = 0; i < managementParams.components.length; i++) {
            if (
                weights[managementParams.components[i]] >
                managementParams.targetWeights[i]
            ) {
                // Convert component to wNATIVE.
                rebalanceLocals.amountComponent = 0;

                if (managementParams.targetWeights[i] == 0) {
                    // To avoid rounding errors.
                    rebalanceLocals.amountComponent = IERC20Upgradeable(
                        managementParams.components[i]
                    ).balanceOf(address(this));
                } else {
                    rebalanceLocals.amountComponent =
                        ((weights[managementParams.components[i]] -
                            managementParams.targetWeights[i]) *
                            indexTotalSupply) /
                        Constants.PRECISION;
                }

                (
                    rebalanceLocals.amountWNATIVEOut,
                    rebalanceLocals.bestRouter
                ) = IndexStrategyUtils.getAmountOutMax(
                    routers[managementParams.components[i]],
                    rebalanceLocals.amountComponent,
                    managementParams.components[i],
                    managementParams.wNATIVE,
                    dexs,
                    pairData
                );

                uint256 balanceComponent = IERC20Upgradeable(
                    managementParams.components[i]
                ).balanceOf(address(this));

                if (rebalanceLocals.amountComponent > balanceComponent) {
                    rebalanceLocals.amountComponent = balanceComponent;
                }

                rebalanceLocals.amountWNATIVE = IndexStrategyUtils
                    .swapExactTokenForToken(
                        rebalanceLocals.bestRouter,
                        rebalanceLocals.amountComponent,
                        rebalanceLocals.amountWNATIVEOut,
                        managementParams.components[i],
                        managementParams.wNATIVE,
                        dexs,
                        pairData
                    );

                if (
                    rebalanceLocals.amountWNATIVE !=
                    rebalanceLocals.amountWNATIVEOut
                ) {
                    revert Errors.Index_WrongSwapAmount();
                }

                rebalanceLocals.amountWNATIVETotal += rebalanceLocals
                    .amountWNATIVE;
            } else if (
                weights[managementParams.components[i]] <
                managementParams.targetWeights[i]
            ) {
                // Calculate how much wNATIVE is required to buy component.
                rebalanceLocals.amountComponent =
                    ((managementParams.targetWeights[i] -
                        weights[managementParams.components[i]]) *
                        indexTotalSupply) /
                    Constants.PRECISION;

                (rebalanceLocals.amountWNATIVE, ) = IndexStrategyUtils
                    .getAmountInMin(
                        routers[managementParams.components[i]],
                        rebalanceLocals.amountComponent,
                        managementParams.wNATIVE,
                        managementParams.components[i],
                        dexs,
                        pairData
                    );

                rebalanceLocals.requiredWNATIVEs[i] = rebalanceLocals
                    .amountWNATIVE;
                rebalanceLocals.requiredWNATIVETotal += rebalanceLocals
                    .amountWNATIVE;
            }
        }

        if (rebalanceLocals.amountWNATIVETotal == 0) {
            revert Errors.Index_WrongTargetWeights();
        }

        // Convert wNATIVE to component.
        for (uint256 i = 0; i < managementParams.components.length; i++) {
            if (rebalanceLocals.requiredWNATIVEs[i] == 0) {
                continue;
            }

            rebalanceLocals.amountWNATIVE =
                (rebalanceLocals.requiredWNATIVEs[i] *
                    rebalanceLocals.amountWNATIVETotal) /
                rebalanceLocals.requiredWNATIVETotal;

            (
                rebalanceLocals.amountComponentOut,
                rebalanceLocals.bestRouter
            ) = IndexStrategyUtils.getAmountOutMax(
                routers[managementParams.components[i]],
                rebalanceLocals.amountWNATIVE,
                managementParams.wNATIVE,
                managementParams.components[i],
                dexs,
                pairData
            );

            rebalanceLocals.amountComponent = IndexStrategyUtils
                .swapExactTokenForToken(
                    rebalanceLocals.bestRouter,
                    rebalanceLocals.amountWNATIVE,
                    rebalanceLocals.amountComponentOut,
                    managementParams.wNATIVE,
                    managementParams.components[i],
                    dexs,
                    pairData
                );

            if (
                rebalanceLocals.amountComponent !=
                rebalanceLocals.amountComponentOut
            ) {
                revert Errors.Index_WrongSwapAmount();
            }
        }

        // Adjust component's weights.
        for (uint256 i = 0; i < managementParams.components.length; i++) {
            if (managementParams.targetWeights[i] == 0) {
                weights[managementParams.components[i]] = 0;
                continue;
            }

            uint256 componentBalance = IERC20Upgradeable(
                managementParams.components[i]
            ).balanceOf(address(this));

            weights[managementParams.components[i]] =
                (componentBalance * Constants.PRECISION) /
                indexTotalSupply;
        }
    }
}
