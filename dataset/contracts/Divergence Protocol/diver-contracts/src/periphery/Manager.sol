// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC721Enumerable, ERC721 } from "@oz/token/ERC721/extensions/ERC721Enumerable.sol";
import { Multicall } from "@oz/utils/Multicall.sol";
import { Multicall } from "@oz/utils/Multicall.sol";
import { SafeCast } from "@oz/utils/math/SafeCast.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { FixedPoint128 } from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { FixedPoint128 } from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import { BattleInitializer } from "./base/BattleInitializer.sol";
import { LiquidityManagement } from "./base/LiquidityManagement.sol";
import { PeripheryImmutableState } from "./base/PeripheryImmutableState.sol";
import { IBattleActions } from "../core/interfaces/battle/IBattleActions.sol";
import { BattleTradeParams } from "../core/params/BattleTradeParams.sol";
import { TradeType } from "../core/types/enums.sol";
import { TickMath } from "../core/libs/TickMath.sol";
import { Errors } from "../core/errors/Errors.sol";
import { BattleBurnParams } from "../core/params/BattleBurnParams.sol";
import { IBattleActions } from "../core/interfaces/battle/IBattleActions.sol";
import { IBattleState } from "../core/interfaces/battle/IBattleState.sol";
import { PositionInfo, BattleKey, GrowthX128, Owed, LiquidityType, Outcome } from "../core/types/common.sol";
import { IArenaCreation } from "../core/interfaces/IArena.sol";
import { IBattleState } from "../core/interfaces/battle/IBattleState.sol";
import { IManagerState } from "./interfaces/IManagerState.sol";
import { IManager } from "./interfaces/IManager.sol";
import { IManagerLiquidity } from "./interfaces/IManagerActions.sol";
import { AddLiqParams } from "./params/Params.sol";
import { TradeParams } from "./params/Params.sol";
import { PositionState, Position } from "./types/common.sol";

/// @title Manager
contract Manager is IManager, Multicall, ERC721Enumerable, PeripheryImmutableState, BattleInitializer, LiquidityManagement {
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 public nextId;
    mapping(uint256 => Position) private _positions;

    constructor(address _arena, address _weth) ERC721("Divergence Protocol Positions NFT", "DIVER-POS") PeripheryImmutableState(_arena, _weth) { }

    /// @inheritdoc IManagerLiquidity
    function addLiquidity(AddLiqParams calldata params) external override returns (uint256 tokenId, uint128 liquidity, uint256 seed) {
        if (block.timestamp > params.deadline) {
            revert Errors.Deadline();
        }
        AddLiqParams memory p1 = params;
        p1.recipient = address(this);
        address battleAddr;
        (liquidity, seed, battleAddr) = _addLiquidity(p1);

        _mint(params.recipient, (tokenId = nextId++));
        bytes32 pk = keccak256(abi.encodePacked(address(this), params.tickLower, params.tickUpper));
        _positions[tokenId] = Position({
            tokenId: tokenId,
            battleAddr: battleAddr,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity,
            liquidityType: params.liquidityType,
            seed: seed,
            insideLast: IBattleState(battleAddr).positions(pk).insideLast,
            owed: Owed(0, 0, 0, 0),
            state: PositionState.LiquidityAdded,
            spearObligation: 0,
            shieldObligation: 0
        });
        emit LiquidityAdded(battleAddr, params.recipient, tokenId, liquidity, params.liquidityType, seed);
    }

    function updateInsideLast(PositionInfo memory pb, Position storage pm) private {
        unchecked {
            pm.owed.fee += uint128(FullMath.mulDiv(pb.insideLast.fee - pm.insideLast.fee, pm.liquidity, FixedPoint128.Q128));
            pm.owed.collateralIn +=
                uint128(FullMath.mulDiv(pb.insideLast.collateralIn - pm.insideLast.collateralIn, pm.liquidity, FixedPoint128.Q128));
            pm.owed.spearOut += uint128(FullMath.mulDiv(pb.insideLast.spearOut - pm.insideLast.spearOut, pm.liquidity, FixedPoint128.Q128));
            pm.owed.shieldOut += uint128(FullMath.mulDiv(pb.insideLast.shieldOut - pm.insideLast.shieldOut, pm.liquidity, FixedPoint128.Q128));
            pm.insideLast = pb.insideLast;
        }
    }

    /// @inheritdoc IManagerLiquidity
    function removeLiquidity(uint256 tokenId)
        external
        override
        returns (uint256 collateral, uint256 spear, uint256 shield, uint256 spearObligation, uint256 shieldObligation)
    {
        if (_ownerOf(tokenId) != msg.sender) {
            revert Errors.OnlyOwner();
        }
        // pm => position in manager
        Position memory pmMemory = _positions[tokenId];
        if (pmMemory.state != PositionState.LiquidityAdded) {
            revert Errors.LiquidityNotAdded();
        }

        BattleBurnParams memory bp;
        bp.recipient = msg.sender;
        bp.tickLower = pmMemory.tickLower;
        bp.tickUpper = pmMemory.tickUpper;
        bp.liquidityType = pmMemory.liquidityType == LiquidityType.COLLATERAL
            ? LiquidityType.COLLATERAL
            : (pmMemory.liquidityType == LiquidityType.SPEAR ? LiquidityType.SPEAR : LiquidityType.SHIELD);
        bp.liquidityAmount = pmMemory.liquidity;

        IBattleActions(pmMemory.battleAddr).burn(bp);

        // pb => position in battle
        PositionInfo memory pb =
            IBattleState(pmMemory.battleAddr).positions(keccak256(abi.encodePacked(address(this), pmMemory.tickLower, pmMemory.tickUpper)));

        Position storage pmStorage = _positions[tokenId];
        updateInsideLast(pb, pmStorage);
        (collateral, spear, shield, spearObligation, shieldObligation) = getObligation(pmStorage);
        collateral += pmStorage.owed.fee;
        pmStorage.state = PositionState.LiquidityRemoved;
        pmStorage.spearObligation = spearObligation;
        pmStorage.shieldObligation = shieldObligation;

        IBattleActions(pmMemory.battleAddr).collect(msg.sender, collateral, spear, shield);

        emit LiquidityRemoved(tokenId, collateral, spear > shield ? spear : shield);
    }

    function getObligation(Position memory pm)
        private
        pure
        returns (uint256 collateral, uint256 spear, uint256 shield, uint256 spearObligation, uint256 shieldObligation)
    {
        if (pm.liquidityType == LiquidityType.COLLATERAL) {
            spearObligation = pm.owed.spearOut;
            shieldObligation = pm.owed.shieldOut;
            uint256 obligation = spearObligation > shieldObligation ? spearObligation : shieldObligation;
            // minus 1 to avoid rounding error, insure the collateral is enough
            // to pay the obligation
            collateral = pm.owed.collateralIn + pm.seed == obligation ? 0 : pm.owed.collateralIn + pm.seed - obligation - 1;
        } else if (pm.liquidityType == LiquidityType.SPEAR) {
            spearObligation = pm.owed.spearOut > pm.seed ? pm.owed.spearOut - pm.seed : 0;
            shieldObligation = pm.owed.shieldOut;
            uint256 obligation = spearObligation > shieldObligation ? spearObligation : shieldObligation;
            // minus 1 to avoid rounding error, insure the collateral is enough
            // to pay the obligation
            collateral = pm.owed.collateralIn == obligation ? 0 : pm.owed.collateralIn - obligation - 1;
            if (pm.seed > pm.owed.spearOut) {
                spear = pm.seed - pm.owed.spearOut;
            }
        } else {
            spearObligation = pm.owed.spearOut;
            shieldObligation = pm.owed.shieldOut > pm.seed ? pm.owed.shieldOut - pm.seed : 0;
            uint256 obligation = spearObligation > shieldObligation ? spearObligation : shieldObligation;
            // minus 1 to avoid rounding error, insure the collateral is enough
            // to pay the obligation
            collateral = pm.owed.collateralIn == obligation ? 0 : pm.owed.collateralIn - obligation - 1;
            if (pm.seed > pm.owed.shieldOut) {
                shield = pm.seed - pm.owed.shieldOut;
            }
        }
    }

    /// @inheritdoc IManagerLiquidity
    function withdrawObligation(uint256 tokenId) external override {
        Position memory pm = _positions[tokenId];

        if (pm.state != PositionState.LiquidityRemoved) {
            revert Errors.LiquidityNotRemoved();
        }
        Outcome rr = IBattleState(pm.battleAddr).battleOutcome();
        bool isSpearLess = pm.spearObligation < pm.shieldObligation;
        uint256 toLp;
        if (rr == Outcome.ONGOING) {
            revert Errors.BattleNotEnd();
        } else if (rr == Outcome.SPEAR_WIN) {
            if (isSpearLess) {
                toLp = pm.shieldObligation - pm.spearObligation;
            }
        } else {
            if (!isSpearLess) {
                toLp = pm.spearObligation - pm.shieldObligation;
            }
        }
        if (toLp > 0) {
            IBattleActions(pm.battleAddr).withdrawObligation(_ownerOf(tokenId), toLp);
        }
        _positions[tokenId].state = PositionState.ObligationWithdrawn;
        emit ObligationWithdrawn(pm.battleAddr, tokenId, toLp);
    }

    function trade(TradeParams calldata p) external override returns (uint256 amountIn, uint256 amountOut) {
        if (block.timestamp > p.deadline) {
            revert Errors.Deadline();
        }

        address battle = IArenaCreation(arena).getBattle(p.battleKey);
        if (battle == address(0)) {
            revert Errors.BattleNotExist();
        }

        BattleTradeParams memory tps;
        tps.recipient = p.recipient;
        tps.tradeType = p.tradeType;
        tps.amountSpecified = p.amountSpecified;
        tps.data = abi.encode(TradeCallbackData({ battleKey: p.battleKey, payer: msg.sender }));
        if (p.sqrtPriceLimitX96 == 0) {
            if (p.tradeType == TradeType.BUY_SPEAR) {
                tps.sqrtPriceLimitX96 = TickMath.MIN_SQRT_RATIO + 1;
            } else {
                tps.sqrtPriceLimitX96 = TickMath.MAX_SQRT_RATIO - 1;
            }
        } else {
            tps.sqrtPriceLimitX96 = p.sqrtPriceLimitX96;
        }

        // call battle
        (amountIn, amountOut) = IBattleActions(battle).trade(tps);
        if (amountOut < p.amountOutMin) {
            revert Errors.Slippage();
        }
        emit Traded(p.recipient, p.tradeType, amountIn, amountOut);
    }

    function tradeCallback(uint256 cAmount, uint256 sAmount, bytes calldata _data) external override {
        TradeCallbackData memory data = abi.decode(_data, (TradeCallbackData));
        address battle = IArenaCreation(arena).getBattle(data.battleKey);
        if (battle == address(0)) {
            revert Errors.BattleNotExist();
        }
        require(msg.sender == battle, "error");
        pay(data.battleKey.collateral, data.payer, msg.sender, cAmount);
    }

    // ====view====

    /// @inheritdoc IManagerState
    function positions(uint256 tokenId) external view override returns (Position memory) {
        return handlePosition(tokenId);
    }

    function handlePosition(uint256 tokenId) private view returns (Position memory p) {
        p = _positions[tokenId];
        if (p.state == PositionState.LiquidityAdded) {
            unchecked {
                GrowthX128 memory insideLast = IBattleState(p.battleAddr).getInsideLast(p.tickLower, p.tickUpper);
                p.owed.fee += uint128(FullMath.mulDiv(insideLast.fee - p.insideLast.fee, p.liquidity, FixedPoint128.Q128));
                p.owed.collateralIn += uint128(FullMath.mulDiv(insideLast.collateralIn - p.insideLast.collateralIn, p.liquidity, FixedPoint128.Q128));
                p.owed.spearOut += uint128(FullMath.mulDiv(insideLast.spearOut - p.insideLast.spearOut, p.liquidity, FixedPoint128.Q128));
                p.owed.shieldOut += uint128(FullMath.mulDiv(insideLast.shieldOut - p.insideLast.shieldOut, p.liquidity, FixedPoint128.Q128));
                p.insideLast = insideLast;
            }
        }
    }

    /// @inheritdoc IManagerState
    function accountPositions(address account) external view override returns (Position[] memory) {
        uint256 balance = balanceOf(account);
        Position[] memory p = new Position[](balance);
        for (uint256 i = 0; i < balance; i++) {
            p[i] = handlePosition(tokenOfOwnerByIndex(account, i));
        }
        return p;
    }
}
