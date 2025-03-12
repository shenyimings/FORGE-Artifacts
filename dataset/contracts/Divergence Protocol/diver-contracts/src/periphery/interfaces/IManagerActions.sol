// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Owed, LiquidityType, TradeType } from "../../core/types/common.sol";
import { ITradeCallback } from "../../core/interfaces/callback/ITradeCallback.sol";
import { AddLiqParams, TradeParams } from "../params/Params.sol";

interface IManagerLiquidity {
    /// @notice Emitted when liquidity is added
    /// @param battleAddress The address of the battle
    /// @param owner The owner of the position and nft
    /// @param tokenId The id of the nft
    /// @param liquidity The amount of liquidity added to nft
    /// @param liquidityType The type of liquidity added, collateral, spear, or shield
    /// @param seedAmount The amount of seed added to nft, seed is the amount of collateral/spear/shield
    event LiquidityAdded(
        address indexed battleAddress, address indexed owner, uint256 tokenId, uint128 liquidity, LiquidityType liquidityType, uint256 seedAmount
    );

    /// @notice Emitted when liquidity is removed
    /// @param tokenId The id of the nft
    /// @param collateralAmount The amount of collateral that lp got
    /// @param stokenAmount The amount of spear/shield that lp got
    event LiquidityRemoved(uint256 tokenId, uint256 collateralAmount, uint256 stokenAmount);

    event ObligationWithdrawn(address battle, uint256 tokenId, uint256 amount);

    /// @notice add liquidity
    /// @param params The params of add liquidity
    function addLiquidity(AddLiqParams calldata params) external returns (uint256 tokenId, uint128 liquidity, uint256 seed);

    /// @notice remove liquidity, one nft will call this function once
    /// @param tokenId The id of the nft
    /// @return collateral The amount of collateral that lp got
    /// @return spear The amount of spear that lp got
    /// @return shield The amount of shield that lp got
    /// @return spearObligation The amount of spear obligation belong to nft
    /// @return shieldObligation The amount of shield obligation belong to nft
    function removeLiquidity(uint256 tokenId)
        external
        returns (uint256 collateral, uint256 spear, uint256 shield, uint256 spearObligation, uint256 shieldObligation);

    /// @notice withdraw obligation, it will be call after removeLiquidity
    function withdrawObligation(uint256 tokenId) external;
}

interface IManagerTrade is ITradeCallback {
    event Traded(address recipient, TradeType tradeType, uint256 amountIn, uint256 amountOut);

    /// @notice buySpear or buyShield
    /// @param mtp The params of trade
    /// @return amountOut The amount of spear/shield that user who bought spear/shield got
    function trade(TradeParams calldata mtp) external returns (uint256, uint256);
}

interface IManagerActions is IManagerLiquidity, IManagerTrade { }
