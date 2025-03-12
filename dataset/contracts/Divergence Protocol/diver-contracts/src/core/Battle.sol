// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { SafeERC20 } from "@oz/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@oz/token/ERC20/IERC20.sol";
import { SafeCast } from "@oz/utils/math/SafeCast.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickBitmap } from "@uniswap/v3-core/contracts/libraries/TickBitmap.sol";
import { SqrtPriceMath } from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import { FixedPoint128 } from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import { Errors } from "./errors/Errors.sol";
import { IBattle } from "./interfaces/battle/IBattle.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { IBattleBase } from "./interfaces/battle/IBattleActions.sol";
import { IBattleState } from "./interfaces/battle/IBattleState.sol";
import { IBattleInit } from "./interfaces/battle/IBattleInit.sol";
import { IMintCallback } from "./interfaces/callback/IMintCallback.sol";
import { IBattleMintBurn } from "./interfaces/battle/IBattleActions.sol";
import { ISToken } from "./interfaces/ISToken.sol";
import { IOwner } from "./interfaces/IOwner.sol";
import { ITradeCallback } from "./interfaces/callback/ITradeCallback.sol";
import { IArenaState } from "./interfaces/IArena.sol";
import { TickMath } from "./libs/TickMath.sol";
import { Tick } from "./libs/Tick.sol";
import { UpdatePositionParams } from "./params/UpdatePositionParams.sol";
import { Position } from "./libs/Position.sol";
import { DiverSqrtPriceMath } from "./libs/DiverSqrtPriceMath.sol";
import { TradeMath } from "./libs/TradeMath.sol";
import { ModifyPositionParams } from "./params/ModifyPositionParams.sol";
import { BattleMintParams } from "./params/BattleMintParams.sol";
import { BattleBurnParams } from "./params/BattleBurnParams.sol";
import { BattleTradeParams } from "./params/BattleTradeParams.sol";
import { ComputeTradeStepParams } from "./params/ComputeTradeStepParams.sol";
import { DeploymentParams } from "./params/DeploymentParams.sol";
import { TradeCache, TradeState, StepComputations } from "./types/TradeTypes.sol";
import { LiquidityType, BattleKey, Outcome, GrowthX128, TickInfo } from "./types/common.sol";
import { PositionInfo, Fee, Outcome, GrowthX128, TradeType } from "./types/common.sol";

/// @title Battle
contract Battle is IBattle {
    using Tick for mapping(int24 => TickInfo);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => PositionInfo);
    using Position for PositionInfo;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        bool unlocked;
    }

    address public override manager;
    address public arena;
    address public oracle;
    address public override spear;
    address public override shield;

    uint256 public startTS;
    uint128 public liquidity;
    uint128 public maxLiquidityPerTick;
    uint128 public protocolFeeAmount;

    Fee public fee;

    BattleKey private _bk;
    GrowthX128 public global;
    Slot0 public override slot0;
    Outcome public override battleOutcome;

    mapping(int24 => TickInfo) public ticks;
    mapping(int16 => uint256) public tickBitmap;
    mapping(bytes32 => PositionInfo) private _positions;

    modifier lock() {
        if (!slot0.unlocked) {
            revert Errors.Locked();
        }
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    /// @notice init storage state variable, only be caled once
    function initState(DeploymentParams memory params) external override {
        if (_bk.expiries != 0) {
            revert Errors.InitTwice();
        }
        _bk = params.battleKey;
        oracle = params.oracleAddr;
        startTS = block.timestamp;
        fee = params.fee;
        spear = params.spear;
        shield = params.shield;
        arena = address(msg.sender);
    }

    /// @notice init sqrtPriceX96, it will be called once
    function init(uint160 startSqrtPriceX96) external override {
        if (slot0.sqrtPriceX96 != 0) {
            revert Errors.InitTwice();
        }
        slot0 = Slot0({ sqrtPriceX96: startSqrtPriceX96, tick: TickMath.getTickAtSqrtRatio(startSqrtPriceX96), unlocked: true });
        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(1);
        manager = address(msg.sender);
    }

    function _updatePosition(UpdatePositionParams memory params) internal returns (PositionInfo storage position) {
        position = _positions.get(msg.sender, params.mpParams.tickLower, params.mpParams.tickUpper);
        GrowthX128 memory _global = global;

        bool flippedLower;
        bool flippedUpper;
        if (params.mpParams.liquidityDelta != 0) {
            flippedLower = ticks.update(params.mpParams.tickLower, params.tick, params.mpParams.liquidityDelta, _global, maxLiquidityPerTick, false);

            flippedUpper = ticks.update(params.mpParams.tickUpper, params.tick, params.mpParams.liquidityDelta, _global, maxLiquidityPerTick, true);

            if (flippedLower) {
                tickBitmap.flipTick(params.mpParams.tickLower, 1);
            }
            if (flippedUpper) {
                tickBitmap.flipTick(params.mpParams.tickUpper, 1);
            }
        }
        GrowthX128 memory insideLast = ticks.getGrowthInside(params.mpParams.tickLower, params.mpParams.tickUpper, params.tick, _global);
        position.update(params.mpParams.liquidityDelta, insideLast);
        if (params.mpParams.liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(params.mpParams.tickLower);
            }
            if (flippedUpper) {
                ticks.clear(params.mpParams.tickUpper);
            }
        }
    }

    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        if (tickLower >= tickUpper) revert Errors.TickInvalid();
        if (tickLower < TickMath.MIN_TICK) revert Errors.TickInvalid();
        if (tickUpper > TickMath.MAX_TICK) revert Errors.TickInvalid();
    }

    function _modifyPosition(ModifyPositionParams memory params) internal returns (PositionInfo storage position, uint256 seed) {
        checkTicks(params.tickLower, params.tickUpper);
        position = _updatePosition(UpdatePositionParams(params, slot0.tick));
        uint256 csp;
        uint256 csh;
        //
        if (params.liquidityDelta > 0) {
            if (params.liquidityType == LiquidityType.COLLATERAL) {
                if (slot0.tick < params.tickLower) {
                    csp = SqrtPriceMath.getAmount0Delta(
                        TickMath.getSqrtRatioAtTick(params.tickLower),
                        TickMath.getSqrtRatioAtTick(params.tickUpper),
                        uint128(params.liquidityDelta),
                        true
                    );
                } else if (slot0.tick < params.tickUpper) {
                    // current tick is inside the passedÆ’ range
                    csp = SqrtPriceMath.getAmount0Delta(
                        slot0.sqrtPriceX96, TickMath.getSqrtRatioAtTick(params.tickUpper), uint128(params.liquidityDelta), false
                    );
                    csh = SqrtPriceMath.getAmount1Delta(
                        TickMath.getSqrtRatioAtTick(params.tickLower), slot0.sqrtPriceX96, uint128(params.liquidityDelta), false
                    );
                    liquidity += uint128(params.liquidityDelta);
                } else {
                    csh = SqrtPriceMath.getAmount1Delta(
                        TickMath.getSqrtRatioAtTick(params.tickLower),
                        TickMath.getSqrtRatioAtTick(params.tickUpper),
                        uint128(params.liquidityDelta),
                        true
                    );
                }
                seed = csp + csh;
            } else if (params.liquidityType == LiquidityType.SPEAR) {
                seed = DiverSqrtPriceMath.getSTokenDelta(
                    TickMath.getSqrtRatioAtTick(params.tickLower), TickMath.getSqrtRatioAtTick(params.tickUpper), params.liquidityDelta
                ).toUint256();
            } else {
                seed = DiverSqrtPriceMath.getSTokenDelta(
                    TickMath.getSqrtRatioAtTick(params.tickLower), TickMath.getSqrtRatioAtTick(params.tickUpper), params.liquidityDelta
                ).toUint256();
            }
        } else if (params.liquidityDelta < 0) {
            if (slot0.tick >= params.tickLower && slot0.tick < params.tickUpper) {
                liquidity -= uint128(-params.liquidityDelta);
            }
        }
    }

    /// @inheritdoc IBattleMintBurn
    function mint(BattleMintParams memory params) external override lock returns (uint256 seed) {
        if (block.timestamp >= _bk.expiries) {
            revert Errors.BattleEnd();
        }
        // check tick
        if (params.liquidityType == LiquidityType.SPEAR && params.tickLower >= slot0.tick) {
            revert Errors.TickInvalid();
        }
        if (params.liquidityType == LiquidityType.SHIELD && params.tickUpper <= slot0.tick) {
            revert Errors.TickInvalid();
        }
        if (msg.sender != manager) {
            revert Errors.CallerNotManager();
        }

        if (params.amount == 0) {
            revert Errors.ZeroAmount();
        }

        PositionInfo storage positionInfo;
        (positionInfo, seed) = _modifyPosition(
            ModifyPositionParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityType: params.liquidityType,
                liquidityDelta: int128(params.amount)
            })
        );

        if (params.liquidityType == LiquidityType.COLLATERAL) {
            uint256 balanceBefore = IERC20(_bk.collateral).balanceOf(address(this));
            IMintCallback(msg.sender).mintCallback(seed, params.data);
            if (IERC20(_bk.collateral).balanceOf(address(this)) < balanceBefore + seed) {
                revert Errors.InsufficientCollateral();
            }
        } else if (params.liquidityType == LiquidityType.SPEAR) {
            uint256 balanceBefore = IERC20(spear).balanceOf(address(this));
            IMintCallback(msg.sender).mintCallback(seed, params.data);
            if (IERC20(spear).balanceOf(address(this)) < balanceBefore + seed) {
                revert Errors.InsufficientSpear();
            }
            ISToken(spear).burn(address(this), seed);
        } else {
            uint256 balanceBefore = IERC20(shield).balanceOf(address(this));
            IMintCallback(msg.sender).mintCallback(seed, params.data);
            if (IERC20(shield).balanceOf(address(this)) < balanceBefore + seed) {
                revert Errors.InsufficientShield();
            }
            ISToken(shield).burn(address(this), seed);
        }

        emit Minted(msg.sender, params.liquidityType, params.tickLower, params.tickUpper, params.amount, seed);
    }

    /// @inheritdoc IBattleMintBurn
    function burn(BattleBurnParams memory params) external override lock {
        if (msg.sender != manager) {
            revert Errors.CallerNotManager();
        }
        if (params.tickLower >= params.tickUpper) {
            revert Errors.TickOrderInvalid();
        }
        _modifyPosition(
            ModifyPositionParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityType: params.liquidityType,
                liquidityDelta: -int128(params.liquidityAmount)
            })
        );
        emit Burned(params.recipient, params.tickLower, params.tickUpper, params.liquidityType, params.liquidityAmount);
    }

    /// comments see IBattleTrade
    function collect(address recipient, uint256 cAmount, uint256 spAmount, uint256 shAmount) external override {
        if (msg.sender != manager) {
            revert Errors.CallerNotManager();
        }
        if (cAmount > 0) {
            IERC20(_bk.collateral).safeTransfer(recipient, cAmount);
        }
        if (spAmount > 0) {
            ISToken(spear).mint(recipient, spAmount);
        }
        if (shAmount > 0) {
            ISToken(shield).mint(recipient, shAmount);
        }
    }

    /// comments see IBattleTrade
    function trade(BattleTradeParams memory params) external returns (uint256 cAmount, uint256 sAmount) {
        if (block.timestamp >= _bk.expiries) {
            revert Errors.BattleEnd();
        }
        // manager or quoter need call this function
        // if (msg.sender != s.manager) {
        //     revert Errors.CallerNotManager();
        // }
        if (params.amountSpecified == 0) {
            revert Errors.ZeroAmount();
        }

        Slot0 memory slot0Start = slot0;

        if (!slot0Start.unlocked) {
            revert Errors.Locked();
        }

        bool isPriceDown = params.tradeType == TradeType.BUY_SPEAR;
        require(
            isPriceDown
                ? params.sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && params.sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : params.sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && params.sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            "PriceInvalid"
        );
        slot0.unlocked = false;

        TradeCache memory cache = TradeCache({ feeProtocol: fee.protocolFee });
        TradeState memory state = TradeState({
            amountSpecifiedRemaining: params.amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0Start.sqrtPriceX96,
            tick: slot0Start.tick,
            global: global,
            protocolFee: 0,
            liquidity: liquidity,
            transactionFee: 0
        });
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != params.sqrtPriceLimitX96) {
            StepComputations memory step;
            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(state.tick, 1, isPriceDown);
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            }
            if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);
            (state.sqrtPriceX96, step.amountIn, step.amountOut) = TradeMath.computeTradeStep(
                ComputeTradeStepParams({
                    tradeType: params.tradeType,
                    sqrtRatioCurrentX96: state.sqrtPriceX96,
                    sqrtRatioTargetX96: 
                    (isPriceDown ? step.sqrtPriceNextX96 < params.sqrtPriceLimitX96 : step.sqrtPriceNextX96 > params.sqrtPriceLimitX96)
                        ? params.sqrtPriceLimitX96
                        : step.sqrtPriceNextX96,
                    liquidity: state.liquidity,
                    amountRemaining: state.amountSpecifiedRemaining
                })
            );

            state.amountSpecifiedRemaining -= step.amountIn;
            state.amountCalculated += step.amountOut;

            step.feeAmount = FullMath.mulDiv(step.amountOut, fee.transactionFee, 1e6);
            if (cache.feeProtocol > 0) {
                uint256 delta = FullMath.mulDiv(step.feeAmount, cache.feeProtocol, 1e6);
                step.feeAmount -= delta;
                state.protocolFee += uint128(delta);
            }

            if (state.liquidity > 0) {
                unchecked {
                    state.global.fee += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);
                    state.transactionFee += step.feeAmount;
                    state.global.collateralIn += FullMath.mulDiv(step.amountIn, FixedPoint128.Q128, state.liquidity);

                    if (params.tradeType == TradeType.BUY_SPEAR) {
                        // buy spear => spearBought and shieldBankOut need be
                        // considered
                        // spear bought
                        state.global.spearOut += FullMath.mulDiv(step.amountOut, FixedPoint128.Q128, state.liquidity);
                    } else {
                        // buy shield => shieldBought and spearBankOut need be
                        // considered
                        state.global.shieldOut += FullMath.mulDiv(step.amountOut, FixedPoint128.Q128, state.liquidity);
                    }
                }
            }

            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    int128 liquidityNet = ticks.cross(step.tickNext, state.global);
                    if (isPriceDown) {
                        liquidityNet = -liquidityNet;
                    }
                    state.liquidity = liquidityNet < 0 ? state.liquidity - uint128(-liquidityNet) : state.liquidity + uint128(liquidityNet);
                }
                state.tick = isPriceDown ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        if (state.tick != slot0Start.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
        } else {
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }
        liquidity = state.liquidity;
        global = state.global;
        cAmount = params.amountSpecified - state.amountSpecifiedRemaining + state.transactionFee + state.protocolFee;
        sAmount = state.amountCalculated;
        if (state.protocolFee > 0) {
            protocolFeeAmount += state.protocolFee;
        }

        uint256 colBalanceBefore = collateralBalance();
        ITradeCallback(msg.sender).tradeCallback(cAmount, sAmount, params.data);
        if (colBalanceBefore + cAmount > collateralBalance()) {
            revert Errors.InsufficientCollateral();
        }

        if (params.tradeType == TradeType.BUY_SPEAR) {
            // mint spear to user
            ISToken(spear).mint(params.recipient, sAmount);
        } else {
            // mint shield to user
            ISToken(shield).mint(params.recipient, sAmount);
        }
        emit Traded(params.recipient, state.liquidity, cAmount, sAmount, params.tradeType, state.sqrtPriceX96, state.tick);
        slot0.unlocked = true;
    }

    /// @inheritdoc IBattleBase
    function settle() external override {
        if (block.timestamp < _bk.expiries) {
            revert Errors.BattleNotEnd();
        }
        if (battleOutcome != Outcome.ONGOING) {
            revert Errors.BattleSettled();
        }
        uint256 price = IOracle(oracle).updatePriceByExternal(_bk.underlying, _bk.expiries);
        if (price == 0) {
            revert Errors.OraclePriceError();
        }
        if (price >= _bk.strikeValue) {
            battleOutcome = Outcome.SPEAR_WIN;
        } else {
            battleOutcome = Outcome.SHIELD_WIN;
        }
        emit Settled(msg.sender, battleOutcome);
    }

    /// @inheritdoc IBattleBase
    function exercise() external override lock {
        if (battleOutcome == Outcome.ONGOING) {
            revert Errors.BattleNotEnd();
        }
        uint256 amount;
        bool wasSpearWon = battleOutcome == Outcome.SPEAR_WIN;
        if (wasSpearWon) {
            amount = IERC20(spear).balanceOf(msg.sender);
        } else {
            amount = IERC20(shield).balanceOf(msg.sender);
        }
        if (amount > 0) {
            if (wasSpearWon) {
                ISToken(spear).burn(msg.sender, amount);
            } else {
                ISToken(shield).burn(msg.sender, amount);
            }
            uint256 exerciseFeeAmount = FullMath.mulDiv(amount, fee.exerciseFee, 1e6);
            if (exerciseFeeAmount > 0) {
                amount -= exerciseFeeAmount;
                protocolFeeAmount += uint128(exerciseFeeAmount);
            }
            IERC20(_bk.collateral).safeTransfer(msg.sender, amount);
            emit Exercised(msg.sender, wasSpearWon, amount);
        }
    }

    /// @inheritdoc IBattleBase
    function withdrawObligation(address recipient, uint256 amount) external override lock {
        if (battleOutcome == Outcome.ONGOING) {
            revert Errors.BattleNotEnd();
        }
        if (msg.sender != manager) {
            revert Errors.CallerNotManager();
        }
        IERC20(_bk.collateral).safeTransfer(recipient, amount);
        emit ObligationWithdrawed(recipient, amount);
    }

    /// comments see IBattleTrade
    function collectProtocolFee(address recipient) external override lock {
        require(IOwner(arena).owner() == msg.sender, "only owner");
        uint256 _fee = protocolFeeAmount;
        protocolFeeAmount = 0;
        IERC20(_bk.collateral).safeTransfer(recipient, _fee);
        emit ProtocolFeeCollected(recipient, _fee);
    }

    function collateralBalance() private view returns (uint256) {
        return IERC20(_bk.collateral).balanceOf(address(this));
    }

    function positions(bytes32 positionKeyB32) external view override returns (PositionInfo memory info) {
        info = _positions[positionKeyB32];
    }

    function battleKey() external view override returns (BattleKey memory) {
        return _bk;
    }

    function startAndEndTS() external view override returns (uint256, uint256) {
        return (startTS, _bk.expiries);
    }

    function spearBalanceOf(address account) external view override returns (uint256 amount) {
        amount = IERC20(spear).balanceOf(account);
    }

    function shieldBalanceOf(address account) external view override returns (uint256 amount) {
        amount = IERC20(shield).balanceOf(account);
    }

    function spearAndShield() external view override returns (address, address) {
        return (spear, shield);
    }

    function getInsideLast(int24 tickLower, int24 tickUpper) external view override returns (GrowthX128 memory) {
        return ticks.getGrowthInside(tickLower, tickUpper, slot0.tick, global);
    }
}
