// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Errors } from "../libraries/Errors.sol";
import { MintingData, MintParams } from "../Common.sol";
import { SwapAdapter } from "../libraries/SwapAdapter.sol";
import { IndexStrategyUtils } from "./IndexStrategyUtils.sol";
import { IIndexToken } from "../interfaces/IIndexToken.sol";
import { Constants } from "../libraries/Constants.sol";
import { INATIVE } from "../dependencies/INATIVE.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

library IndexStrategyMint {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SwapAdapter for SwapAdapter.Setup;

    struct MintIndexFromTokenLocals {
        address bestRouter;
        MintingData mintingData;
    }

    /**
     * @dev Mints index tokens in exchange for a specified token.
     * @param mintParams The mint parameters that species the minting details.
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param weights The datastructure describing component weights.
     * @param routers The datastructure describing routers (used for swapping).
     * @return amountIndex The amount of index tokens minted.
     * @return amountToken The amount of tokens swapped.
     */
    function mintIndexFromToken(
        MintParams memory mintParams,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => uint256) storage weights,
        mapping(address => address[]) storage routers
    ) external returns (uint256 amountIndex, uint256 amountToken) {
        MintIndexFromTokenLocals memory mintIndexFromTokenLocals;

        if (mintParams.recipient == address(0)) {
            revert Errors.Index_ZeroAddress();
        }

        (
            amountToken,
            mintIndexFromTokenLocals.bestRouter,
            mintIndexFromTokenLocals.mintingData
        ) = getMintingDataFromToken(
            mintParams,
            pairData,
            dexs,
            weights,
            routers
        );

        if (amountToken > mintParams.amountTokenMax) {
            revert Errors.Index_AboveMaxAmount();
        }

        if (
            mintIndexFromTokenLocals.mintingData.amountIndex <
            mintParams.amountIndexMin
        ) {
            revert Errors.Index_BelowMinAmount();
        }

        amountIndex = mintIndexFromTokenLocals.mintingData.amountIndex;

        IERC20Upgradeable(mintParams.token).safeTransferFrom(
            mintParams.msgSender,
            address(this),
            amountToken
        );

        uint256 amountTokenSpent = IndexStrategyUtils.swapTokenForExactToken(
            mintIndexFromTokenLocals.bestRouter,
            mintIndexFromTokenLocals.mintingData.amountWNATIVETotal,
            amountToken,
            mintParams.token,
            mintParams.wNATIVE,
            dexs,
            pairData
        );

        if (amountTokenSpent != amountToken) {
            revert Errors.Index_WrongSwapAmount();
        }

        uint256 amountWNATIVESpent = mintExactIndexFromWNATIVE(
            mintIndexFromTokenLocals.mintingData,
            mintParams.recipient,
            mintParams.components,
            mintParams.wNATIVE,
            mintParams.indexToken,
            dexs,
            pairData
        );

        if (
            amountWNATIVESpent !=
            mintIndexFromTokenLocals.mintingData.amountWNATIVETotal
        ) {
            revert Errors.Index_WrongSwapAmount();
        }
    }

    /**
     * @dev Mints index tokens by swapping the native asset (such as Ether).
     * @param mintParams The mint parameters that species the minting details.
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param weights The datastructure describing component weights.
     * @param routers The datastructure describing routers (used for swapping).
     * @return amountIndex The amount of index tokens minted.
     * @return amountNATIVE The amount of native tokens swapped.
     */
    function mintIndexFromNATIVE(
        MintParams memory mintParams,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => uint256) storage weights,
        mapping(address => address[]) storage routers
    ) external returns (uint256 amountIndex, uint256 amountNATIVE) {
        MintingData memory mintingData = getMintingDataFromWNATIVE(
            mintParams.amountTokenMax,
            mintParams,
            routers,
            pairData,
            dexs,
            weights
        );

        if (mintingData.amountWNATIVETotal > mintParams.amountTokenMax) {
            revert Errors.Index_AboveMaxAmount();
        }

        if (mintingData.amountIndex < mintParams.amountIndexMin) {
            revert Errors.Index_BelowMinAmount();
        }

        amountIndex = mintingData.amountIndex;
        amountNATIVE = mintingData.amountWNATIVETotal;

        INATIVE(mintParams.wNATIVE).deposit{
            value: mintingData.amountWNATIVETotal
        }();

        uint256 amountWNATIVESpent = mintExactIndexFromWNATIVE(
            mintingData,
            mintParams.recipient,
            mintParams.components,
            mintParams.wNATIVE,
            mintParams.indexToken,
            dexs,
            pairData
        );

        if (amountWNATIVESpent != mintingData.amountWNATIVETotal) {
            revert Errors.Index_WrongSwapAmount();
        }

        uint256 amountNATIVERefund = mintParams.amountTokenMax - amountNATIVE;

        if (amountNATIVERefund > 0) {
            payable(mintParams.msgSender).transfer(amountNATIVERefund);
        }
    }

    /**
     * @dev Calculates the minting data from the given token and maximum token amount.
     * @param mintParams The mint parameters that species the minting details.
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param weights The datastructure describing component weights.
     * @param routers The datastructure describing routers (used for swapping).
     * @return amountToken The actual token amount used for minting.
     * @return bestRouter The best router to use for minting.
     * @return mintingData The minting data containing information about the components, routers, and wNATIVE amounts.
     */
    function getMintingDataFromToken(
        MintParams memory mintParams,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => uint256) storage weights,
        mapping(address => address[]) storage routers
    )
        public
        returns (
            uint256 amountToken,
            address bestRouter,
            MintingData memory mintingData
        )
    {
        (uint256 amountWNATIVE, ) = IndexStrategyUtils.getAmountOutMax(
            routers[mintParams.token],
            mintParams.amountTokenMax,
            mintParams.token,
            mintParams.wNATIVE,
            dexs,
            pairData
        );

        mintingData = getMintingDataFromWNATIVE(
            amountWNATIVE,
            mintParams,
            routers,
            pairData,
            dexs,
            weights
        );

        (amountToken, bestRouter) = IndexStrategyUtils.getAmountInMin(
            routers[mintParams.token],
            mintingData.amountWNATIVETotal,
            mintParams.token,
            mintParams.wNATIVE,
            dexs,
            pairData
        );
    }

    /**
     * @dev Mints the exact index amount of the index token by swapping components with wNATIVE.
     * @param mintingData The minting data containing information about the components and routers.
     * @param recipient The address to receive the minted index tokens.
     * @param components The components that make up the index.
     * @param wNATIVE The address of the wrapped native currency.
     * @param indexToken The address of the indexToken.
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @return amountWNATIVESpent The amount of wNATIVE spent during the minting process.
     */
    function mintExactIndexFromWNATIVE(
        MintingData memory mintingData,
        address recipient,
        address[] memory components,
        address wNATIVE,
        IIndexToken indexToken,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData
    ) internal returns (uint256 amountWNATIVESpent) {
        for (uint256 i = 0; i < components.length; i++) {
            if (mintingData.amountComponents[i] == 0) {
                continue;
            }

            amountWNATIVESpent += IndexStrategyUtils.swapTokenForExactToken(
                mintingData.bestRouters[i],
                mintingData.amountComponents[i],
                mintingData.amountWNATIVEs[i],
                wNATIVE,
                components[i],
                dexs,
                pairData
            );
        }

        indexToken.mint(recipient, mintingData.amountIndex);
    }

    /**
     * @dev Calculates the minting data from the given wNATIVE amount.
     * @param amountWNATIVEMax The maximum wNATIVE amount to use for minting.
     * @param mintParams The mint parameters that species the minting details.
     * @param routers The datastructure describing routers (used for swapping).
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param weights The datastructure describing component weights.
     * @return mintingData The minting data containing information about the components, routers, and wNATIVE amounts.
     */
    function getMintingDataFromWNATIVE(
        uint256 amountWNATIVEMax,
        MintParams memory mintParams,
        mapping(address => address[]) storage routers,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => uint256) storage weights
    ) public returns (MintingData memory mintingData) {
        MintingData memory mintingDataUnit = getMintingDataForExactIndex(
            Constants.PRECISION,
            dexs,
            pairData,
            weights,
            mintParams.components,
            routers,
            mintParams.wNATIVE
        );

        uint256 amountIndex = type(uint256).max;

        for (uint256 i = 0; i < mintParams.components.length; i++) {
            if (mintingDataUnit.amountWNATIVEs[i] == 0) {
                continue;
            }

            uint256 amountWNATIVE = (amountWNATIVEMax *
                mintingDataUnit.amountWNATIVEs[i]) /
                mintingDataUnit.amountWNATIVETotal;

            if (amountWNATIVE == 0) {
                continue;
            }

            (uint256 amountComponent, ) = IndexStrategyUtils.getAmountOutMax(
                routers[mintParams.components[i]],
                amountWNATIVE,
                mintParams.wNATIVE,
                mintParams.components[i],
                dexs,
                pairData
            );

            amountIndex = MathUpgradeable.min(
                amountIndex,
                (amountComponent * Constants.PRECISION) /
                    weights[mintParams.components[i]]
            );
        }

        mintingData = IndexStrategyMint.getMintingDataForExactIndex(
            amountIndex,
            dexs,
            pairData,
            weights,
            mintParams.components,
            routers,
            mintParams.wNATIVE
        );
    }

    /**
     * @dev Calculates the minting data for the exact index amount.
     * @param amountIndex The exact index amount to mint.
     * @param dexs The datastructure describing dexes (used for swapping).
     * @param pairData The datastructure describing swapping pairs (used for swapping).
     * @param weights The datastructure describing component weights.
     * @param components The components that make up the index.
     * @param routers The datastructure describing routers (used for swapping).
     * @param wNATIVE The address of the wrapped native currency.
     * @return mintingData The minting data containing information about the components, routers, and wNATIVE amounts.
     */
    function getMintingDataForExactIndex(
        uint256 amountIndex,
        mapping(address => SwapAdapter.DEX) storage dexs,
        mapping(address => mapping(address => mapping(address => SwapAdapter.PairData)))
            storage pairData,
        mapping(address => uint256) storage weights,
        address[] memory components,
        mapping(address => address[]) storage routers,
        address wNATIVE
    ) internal returns (MintingData memory mintingData) {
        mintingData.amountIndex = amountIndex;
        mintingData.amountWNATIVEs = new uint256[](components.length);
        mintingData.bestRouters = new address[](components.length);
        mintingData.amountComponents = new uint256[](components.length);

        for (uint256 i = 0; i < components.length; i++) {
            if (weights[components[i]] == 0) {
                continue;
            }

            mintingData.amountComponents[i] =
                (amountIndex * weights[components[i]]) /
                Constants.PRECISION;

            (
                mintingData.amountWNATIVEs[i],
                mintingData.bestRouters[i]
            ) = IndexStrategyUtils.getAmountInMin(
                routers[components[i]],
                mintingData.amountComponents[i],
                wNATIVE,
                components[i],
                dexs,
                pairData
            );

            mintingData.amountWNATIVETotal += mintingData.amountWNATIVEs[i];
        }
    }
}
