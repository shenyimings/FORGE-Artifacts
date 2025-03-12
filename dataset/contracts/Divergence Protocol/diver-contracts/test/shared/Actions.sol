// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { CreateAndInitBattleParams } from "../../src/periphery/params/Params.sol";
import { IBattleInitializer } from "../../src/periphery/interfaces/IBattleInitializer.sol";
import { AddLiqParams, TradeParams } from "../../src/periphery/params/Params.sol";
import { IManager } from "../../src/periphery/interfaces/IManager.sol";
import { IBattle } from "../../src/core/interfaces/battle/IBattle.sol";
import { IBattleBase } from "../../src/core/interfaces/battle/IBattleActions.sol";
import { BattleKey, LiquidityType, TradeType } from "../../src/core/types/common.sol";
import { Position } from "../../src/periphery/types/common.sol";
import { console2 } from "@std/console2.sol";
import { ERC721Enumerable } from "@oz/token/ERC721/extensions/ERC721Enumerable.sol";

function getBattleKey(address collateral, string memory underlying, uint256 expiries, uint256 strikeValue) pure returns (BattleKey memory) {
    return BattleKey({ collateral: collateral, underlying: underlying, expiries: expiries, strikeValue: strikeValue });
}

function getCreateBattleParams(BattleKey memory bk, address oracle, uint160 startSqrtPriceX96) pure returns (CreateAndInitBattleParams memory) {
    return CreateAndInitBattleParams({ oracle: oracle, battleKey: bk, sqrtPriceX96: startSqrtPriceX96 });
}

function createBattle(address manager, CreateAndInitBattleParams memory params) returns (address battle) {
    battle = IBattleInitializer(manager).createAndInitializeBattle(params);
}

function getAddLiquidityParams(
    BattleKey memory bk,
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    LiquidityType liquidityType,
    uint128 amount,
    uint256 deadPeriod
)
    view
    returns (AddLiqParams memory)
{
    return AddLiqParams({
        battleKey: bk,
        recipient: recipient,
        tickLower: tickLower,
        tickUpper: tickUpper,
        liquidityType: liquidityType,
        amount: amount,
        deadline: block.timestamp + deadPeriod
    });
}

function addLiquidity(address sender, address manager, AddLiqParams memory params) {
    IManager(manager).addLiquidity(params);
    console2.log("log@ =====>begin addLiquidity user: %s <======", sender);
    console2.log("log@ battleKey collateral: %s", params.battleKey.collateral);
    console2.log("log@ battleKey underlying: %s", params.battleKey.underlying);
    console2.log("log@ battleKey expiries: %s", uint256(params.battleKey.expiries));
    console2.log("log@ battleKey strikeValue: %s", params.battleKey.strikeValue);
    console2.log("log@ recipient: %s", params.recipient);
    console2.log("log@ tickLower: %s", params.tickLower);
    console2.log("log@ tickUpper: %s", params.tickUpper);
    console2.log("log@ liquidityType: %s", uint256(params.liquidityType));
    console2.log("log@ amount: %s", params.amount);
    console2.log("log@ =====>end addLiquidity user: %s <======", sender);
}

function removeLiquidity(address sender, address manager, uint256 tokenId) {
    IManager(manager).removeLiquidity(tokenId);
    console2.log("log@ =====>begin removeLiquidity user: %s <======", sender);
    console2.log("log@ tokenId: %s", tokenId);
    console2.log("log@ =====>end removeLiquidity user: %s <======", sender);
}

function getTradeParams(
    BattleKey memory bk,
    TradeType ta,
    uint256 amount,
    address recipient,
    uint256 amountOutMin,
    uint160 sqrtPriceLimitX96,
    uint256 deadPeriod
)
    view
    returns (TradeParams memory)
{
    return TradeParams({
        battleKey: bk,
        tradeType: ta,
        amountSpecified: amount,
        recipient: recipient,
        amountOutMin: amountOutMin,
        sqrtPriceLimitX96: sqrtPriceLimitX96,
        deadline: block.timestamp + deadPeriod
    });
}

function trade(address sender, address manager, TradeParams memory params) returns (uint256 amtIn, uint256 amtOut) {
    console2.log("log@ =====>begin trade user: %s <======", sender);

    (amtIn, amtOut) = IManager(manager).trade(params);
    console2.log("log@ amtIn: %s", params.amountSpecified);
    console2.log("log@ amtOut: %s", amtOut);
    console2.log("log@ battleKey collateral: %s", params.battleKey.collateral);
    console2.log("log@ battleKey underlying: %s", params.battleKey.underlying);
    console2.log("log@ battleKey expiries: %s", uint256(params.battleKey.expiries));
    console2.log("log@ battleKey strikeValue: %s", params.battleKey.strikeValue);
    console2.log("log@ tradeType: %s", uint256(params.tradeType));
    console2.log("log@ amountSpecified: %s", params.amountSpecified);
    console2.log("log@ recipient: %s", params.recipient);
    console2.log("log@ amountOutMin: %s", params.amountOutMin);
    console2.log("log@ sqrtPriceLimitX96: %s", params.sqrtPriceLimitX96);
    for (uint256 id; id < ERC721Enumerable(manager).totalSupply(); id++) {
        positionTokenId(id, manager);
    }

    console2.log("log@ =====>end trade user: %s <======", sender);
    console2.log("log@ ");
    return (params.amountSpecified, amtOut);
}

function exercise(address sender, address battle) {
    IBattle(battle).exercise();
    console2.log("log@ =====>begin exercise user: %s <======", sender);
    console2.log("log@ =====>end exercise user: %s <======", sender);
    console2.log("log@ ");
}

function settle(address sender, address battle) {
    IBattleBase(battle).settle();
    console2.log("log@ =====>begin settle user: %s <======", sender);
    console2.log("log@ =====>end settle user: %s <======", sender);
    console2.log("log@ ");
}

function withdrawObligation(address sender, address manager, uint256 tokenId) {
    IManager(manager).withdrawObligation(tokenId);
    console2.log("log@ =====>begin withdrawObligation user: %s <======", sender);
    console2.log("log@ tokenId: %s", tokenId);
    for (uint256 id; id < ERC721Enumerable(manager).totalSupply(); id++) {
        positionTokenId(id, manager);
    }
    console2.log("log@ =====>end withdrawObligation user: %s <======", sender);
    console2.log("log@ ");
}

function position(address sender, address manager) {
    Position[] memory ps = IManager(manager).accountPositions(sender);
    console2.log("log@ =====>begin position user: %s <======", sender);
    for (uint256 i; i < ps.length; i++) {
        Position memory p = ps[i];
        console2.log("log@ position tokenId: %s", p.tokenId);
        console2.log("log@ owed fee: %s", p.owed.fee);
        console2.log("log@ owed collateralIn: %s", p.owed.collateralIn);
        console2.log("log@ owed spearOut: %s", p.owed.spearOut);
        console2.log("log@ owed shieldOut: %s", p.owed.shieldOut);
        console2.log("log@ liquidity: %s", p.liquidity);
        console2.log("log@ tickLower: %s", p.tickLower);
        console2.log("log@ tickUpper: %s", p.tickUpper);
        console2.log("log@ seed: %s", p.seed);
        console2.log("log@ spearObligation: %s", p.spearObligation);
        console2.log("log@ shieldObligation: %s", p.shieldObligation);
        console2.log("log@ inside fee: %s", p.insideLast.fee);
        console2.log("log@ inside collateralIn: %s", p.insideLast.collateralIn);
        console2.log("log@ inside spearOut: %s", p.insideLast.spearOut);
        console2.log("log@ inside shieldOut: %s", p.insideLast.shieldOut);
    }
    console2.log("log@ =====>end position user: %s <======", sender);
}

function positionTokenId(uint256 tokenId, address manager) {
    Position memory p = IManager(manager).positions(tokenId);
    address sender = ERC721Enumerable(manager).ownerOf(tokenId);
    console2.log("log@ =====>begin position user: %s <======", sender);
    console2.log("log@ position tokenId: %s", p.tokenId);
    console2.log("log@ owed fee: %s", p.owed.fee);
    console2.log("log@ owed collateralIn: %s", p.owed.collateralIn);
    console2.log("log@ owed spearOut: %s", p.owed.spearOut);
    console2.log("log@ owed shieldOut: %s", p.owed.shieldOut);
    console2.log("log@ liquidity: %s", p.liquidity);
    console2.log("log@ tickLower: %s", p.tickLower);
    console2.log("log@ tickUpper: %s", p.tickUpper);
    console2.log("log@ seed: %s", p.seed);
    console2.log("log@ spearObligation: %s", p.spearObligation);
    console2.log("log@ shieldObligation: %s", p.shieldObligation);
    console2.log("log@ inside fee: %s", p.insideLast.fee);
    console2.log("log@ inside collateralIn: %s", p.insideLast.collateralIn);
    console2.log("log@ inside spearOut: %s", p.insideLast.spearOut);
    console2.log("log@ inside shieldOut: %s", p.insideLast.shieldOut);
    console2.log("log@ =====>end position user: %s <======", sender);
}

function settle(address battle) {
    IBattle(battle).settle();
}
