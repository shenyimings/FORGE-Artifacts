// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { BattleMintParams } from "../../params/BattleMintParams.sol";
import { BattleBurnParams } from "../../params/BattleBurnParams.sol";
import { BattleTradeParams } from "../../params/BattleTradeParams.sol";
import { PositionInfo, TradeType, Outcome, LiquidityType } from "../../types/common.sol";

interface IBattleMintBurn {
    /// @param sender The address who minted the liquidity
    /// @param liquidityType The type of liquidity minted
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param liquidity The amount of liquidity minted
    /// @param seedAmount The amount of collateral/spear/shield(according to liquidityType) spent
    event Minted(address indexed sender, LiquidityType liquidityType, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 seedAmount);

    /// @param sender The address who burned the liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param liquidityType The type of liquidity burned
    /// @param liquidityAmount The amount of liquidity burned
    event Burned(address indexed sender, int24 tickLower, int24 tickUpper, LiquidityType liquidityType, uint128 liquidityAmount);

    /// @notice Mint liquidity
    /// @param mp The params of mint
    /// @return seed The amount of collateral/spear/shield(according to liquidityType) spent
    function mint(BattleMintParams memory mp) external returns (uint256 seed);

    // / @notice Burn liquidity for a slot
    // / @dev
    // / @return spearAmount The amount of spear tokens to be removed from curve
    // / @return shieldAmount The amount of shield tokens to be removed from
    // curve
    function burn(BattleBurnParams memory BurnParams) external;

    /// @notice transfer collateral/spear/shield to lp
    /// @dev only called by Manager contract
    /// @param recipient The address who receive collateral/spear/shield
    /// @param cAmount The amount of collateral to be transfered
    /// @param spAmount The amount of spear to be transfered
    /// @param shAmount The amount of shield to be transfered
    function collect(address recipient, uint256 cAmount, uint256 spAmount, uint256 shAmount) external;
}

/// @title IBattleTrade
interface IBattleTrade {
    /// @notice trade spear/shield for collateral
    /// @param recipient The address who receive spear/shield
    /// @param liquidity liquity in battle after trade
    /// @param amountIn The amount of spear/shield to be traded
    /// @param amountOut The amount of collateral to be traded
    /// @param tradeType buySpard or buyShield
    /// @param sqrtPriceX96 The sqrt price of the battle after trade
    /// @param tick The tick of the battle after trade
    event Traded(
        address indexed recipient, uint128 liquidity, uint256 amountIn, uint256 amountOut, TradeType tradeType, uint160 sqrtPriceX96, int24 tick
    );

    event ProtocolFeeCollected(address recipient, uint256 amount);

    /// @notice trade spear/shield for collateral
    /// @param tp The params of trade
    /// @return cAmount The amount of collateral user spent
    /// @return sAmount The amount of spear/shield user received
    function trade(BattleTradeParams memory tp) external returns (uint256 cAmount, uint256 sAmount);

    /// @notice collect protocol fee
    function collectProtocolFee(address recipient) external;
}

interface IBattleBase {
    event ObligationWithdrawed(address recipient, uint256 amount);

    event InternalInitialized(address indexed battleInternal, int24 tick, uint160 sqrtPriceX96, uint256 startTS, uint256 endTS);

    event Settled(address indexed sender, Outcome battleResult);

    event Exercised(address indexed sender, bool spearWin, uint256 amount);

    /// @notice settle the battle
    /// battle will fetch the price of underlying asset, and determinate the
    /// battle result.
    /// battle finished after settle function was called
    function settle() external;

    /// @notice If a user bought some spear/shield and won, he can switch
    /// spear/shield to collateral by 1:1 ratio.
    /// eg. Alice bought 100 spear and the battle result was spear_win, she can
    /// switch 100 collateral by call this
    /// function
    function exercise() external;

    /// @notice Returns the amount of unused collateral to the options seller
    /// after settlement. For options that expire
    /// out-of-money, the amount of collateral obligation reserved prior to
    /// settlement becomes exercisable. Only called
    /// by
    /// the Manager.
    /// @param recipient address which receive collateral
    /// @param amount the amount of collateral will receive
    function withdrawObligation(address recipient, uint256 amount) external;
}

interface IBattleActions is IBattleMintBurn, IBattleTrade, IBattleBase { }
