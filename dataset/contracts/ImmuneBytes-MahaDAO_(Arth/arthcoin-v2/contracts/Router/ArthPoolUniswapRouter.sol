// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IARTH} from '../Arth/IARTH.sol';
import {IARTHPool} from '../Arth/Pools/IARTHPool.sol';
import {IARTHX} from '../ARTHX/IARTHX.sol';
import {IERC20} from '../ERC20/IERC20.sol';
import {ISimpleOracle} from '../Oracle/ISimpleOracle.sol';
import {IStakingRewards} from '../Staking/IStakingRewards.sol';

contract ArthPoolUniswapRouter {
    IARTH private _ARTH;
    IARTHX private _ARTHX;
    IARTHPool private _POOL;
    IERC20 private _COLLATEAL;
    IStakingRewards private _arthStakingPool;
    IStakingRewards private _arthxStakingPool;

    /**
     * Constructor.
     */
    constructor(
        IARTHPool __POOL,
        IARTHX __ARTHX,
        IARTH __ARTH,
        IStakingRewards __arthStakingPool,
        IStakingRewards __arthxStakingPool
    ) {
        _POOL = __POOL;
        _ARTH = __ARTH;
        _ARTHX = __ARTHX;

        _arthStakingPool = __arthStakingPool;
        _arthxStakingPool = __arthxStakingPool;
    }

    /**
     * Public.
     */

    function mint1t1ARTHAndStake(
        uint256 collateralAmount,
        uint256 arthOutMin,
        uint256 lockDuration
    ) public {
        _COLLATEAL.transferFrom(msg.sender, address(this), collateralAmount);

        uint256 arthOut = _POOL.mint1t1ARTH(collateralAmount, arthOutMin);
        _ARTH.approve(address(_arthStakingPool), uint256(arthOut));

        if (lockDuration != 0)
            _arthStakingPool.stakeLockedFor(msg.sender, arthOut, lockDuration);
        else _arthStakingPool.stakeFor(msg.sender, arthOut);
    }

    function mint1t1ARTHAndStakeWithPermit(
        uint256 collateralAmount,
        uint256 arthOutMin,
        uint256 lockDuration,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _ARTH.permit(
            msg.sender,
            address(_arthStakingPool),
            uint256(int256(-1)),
            block.timestamp,
            v,
            r,
            s
        );

        uint256 arthOut = _POOL.mint1t1ARTH(collateralAmount, arthOutMin);

        if (lockDuration != 0)
            _arthStakingPool.stakeLockedFor(msg.sender, arthOut, lockDuration);
        else _arthStakingPool.stakeFor(msg.sender, arthOut);
    }

    function mintAlgorithmicARTHAndStake(
        uint256 arthxAmountD18,
        uint256 arthOutMin,
        uint256 lockDuration
    ) external {
        _ARTHX.transferFrom(msg.sender, address(this), arthxAmountD18);
        uint256 arthOut = _POOL.mintAlgorithmicARTH(arthxAmountD18, arthOutMin);
        _ARTH.approve(address(_arthStakingPool), uint256(arthOut));

        if (lockDuration != 0) {
            _arthStakingPool.stakeLockedFor(msg.sender, arthOut, lockDuration);
        } else {
            _arthStakingPool.stakeFor(msg.sender, arthOut);
        }
    }

    function mintAlgorithmicARTHAndStakeWithPermit(
        uint256 arthxAmountD18,
        uint256 arthOutMin,
        uint256 lockDuration,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _ARTH.permit(
            msg.sender,
            address(_arthStakingPool),
            uint256(int256(-1)),
            block.timestamp,
            v,
            r,
            s
        );

        uint256 arthOut = _POOL.mintAlgorithmicARTH(arthxAmountD18, arthOutMin);

        if (lockDuration != 0)
            _arthStakingPool.stakeLockedFor(msg.sender, arthOut, lockDuration);
        else _arthStakingPool.stakeFor(msg.sender, arthOut);
    }

    function mintFractionalARTHAndStake(
        uint256 collateralAmount,
        uint256 arthxAmount,
        uint256 arthOutMin,
        uint256 lockDuration
    ) external {
        _COLLATEAL.transferFrom(msg.sender, address(this), collateralAmount);
        _ARTHX.transferFrom(msg.sender, address(this), arthxAmount);

        uint256 arthOut =
            _POOL.mintFractionalARTH(collateralAmount, arthxAmount, arthOutMin);
        _ARTH.approve(address(_arthStakingPool), uint256(arthOut));

        if (lockDuration != 0)
            _arthStakingPool.stakeLockedFor(msg.sender, arthOut, lockDuration);
        else _arthStakingPool.stakeFor(msg.sender, arthOut);
    }

    function mintFractionalARTHAndStakeWithPermit(
        uint256 collateralAmount,
        uint256 arthxAmount,
        uint256 arthOutMin,
        uint256 lockDuration,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _ARTH.permit(
            msg.sender,
            address(_arthStakingPool),
            uint256(int256(-1)),
            block.timestamp,
            v,
            r,
            s
        );

        uint256 arthOut =
            _POOL.mintFractionalARTH(collateralAmount, arthxAmount, arthOutMin);

        if (lockDuration != 0)
            _arthStakingPool.stakeLockedFor(msg.sender, arthOut, lockDuration);
        else _arthStakingPool.stakeFor(msg.sender, arthOut);
    }

    function recollateralizeARTHAndStake(
        uint256 collateralAmount,
        uint256 ARTHXOutMin,
        uint256 lockDuration
    ) external {
        _COLLATEAL.transferFrom(msg.sender, address(this), collateralAmount);
        uint256 arthxOut =
            _POOL.recollateralizeARTH(collateralAmount, ARTHXOutMin);
        _ARTHX.approve(address(_arthxStakingPool), uint256(arthxOut));

        if (lockDuration != 0)
            _arthxStakingPool.stakeLockedFor(
                msg.sender,
                arthxOut,
                lockDuration
            );
        else _arthxStakingPool.stakeFor(msg.sender, arthxOut);
    }

    function recollateralizeARTHAndStakeWithPermit(
        uint256 collateralAmount,
        uint256 ARTHXOutMin,
        uint256 lockDuration,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _ARTHX.permit(
            msg.sender,
            address(_arthxStakingPool),
            uint256(int256(-1)),
            block.timestamp,
            v,
            r,
            s
        );

        uint256 arthxOut =
            _POOL.recollateralizeARTH(collateralAmount, ARTHXOutMin);

        if (lockDuration != 0)
            _arthxStakingPool.stakeLockedFor(
                msg.sender,
                arthxOut,
                lockDuration
            );
        else _arthxStakingPool.stakeFor(msg.sender, arthxOut);
    }
}
