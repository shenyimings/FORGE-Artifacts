// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IVotingEscrow {
    /*=== event ===*/

    event Deposit(
        address indexed provider,
        uint value,
        uint end,
        uint lockDuration,
        bool autoExtend,
        LockAction indexed action,
        uint ts
    );
    event Withdraw(address indexed provider, uint value, uint ts);
    event Stake(address indexed provider, uint value, uint ts);
    event Unstake(address indexed provider, uint value, uint ts);
    event Vested(address indexed account, uint value, uint ts);
    event Claimed(address indexed account, uint value, uint ts);

    /*=== struct ===*/

    struct Point {
        int128 bias;
        int128 slope;
        uint ts;
    }

    struct StakedPoint {
        int128 bias;
        int128 slope;
        uint ts;
        uint end; // timestamp to reach max veSYM
    }

    struct Vest {
        uint amount;
        uint ts;
    }

    struct LockedBalance {
        uint amount;
        uint end; // end of lock, used if autoExtend is false, be zero if autoExtend is true
        uint lockDuration; // duration of lock, used if autoExtend is true, be zero if autoExtend is false
        bool autoExtend;
    }

    enum LockAction {
        CREATE_LOCK,
        INCREASE_LOCK_AMOUNT,
        INCREASE_LOCK_TIME
    }

    /*=== function ===*/

    function balanceOf(address _addr) external view returns (uint);

    function balanceOfAt(address _addr, uint _timestamp) external view returns (uint);

    function baseToken() external view returns (address);

    function callbackRelayer() external view returns (address);

    function checkpoint() external;

    function claimVested(address _account) external returns (uint);

    function createLock(uint _value, uint _unlockTime, uint _lockDuration, bool _autoExtend) external;

    function decimals() external view returns (uint8);

    function findUserStaked(address _addr, uint _timestamp) external view returns (uint);

    function findUserVested(address _addr, uint _timestamp) external view returns (uint);

    function findUserPoint(address _addr, uint _timestamp) external view returns (uint);

    function findPoint(uint _timestamp) external view returns (uint);

    function getLastStakedPoint(address _addr) external view returns (StakedPoint memory point);

    function getVested(address _addr) external view returns (uint);

    function userVestAt(address _addr, uint _ts) external view returns (Vest memory);

    function globalEpoch() external view returns (uint);

    function increaseLockAmount(uint _value) external;

    function increaseLockAmountAndUnlockTime(
        uint _value,
        uint _unlockTime,
        uint _lockDuration,
        bool _autoExtend
    ) external;

    function increaseUnlockTime(uint _unlockTime, uint _lockDuration, bool _autoExtend) external;

    function locked(address) external view returns (uint amount, uint end, uint lockDuration, bool autoExtend);

    function lockedBalanceOf(address _addr) external view returns (uint);

    function lockedBalanceOfAt(address _addr, uint _timestamp) external view returns (uint);

    function lockedPointOfAt(address _addr, uint _timestamp) external view returns (Point memory);

    function maxTime() external view returns (uint);

    function name() external view returns (string calldata);

    function pointAt(uint _timestamp) external view returns (Point memory);

    function pointHistory(uint) external view returns (int128 bias, int128 slope, uint ts);

    function slopeChanges(uint) external view returns (int128);

    function stake(uint _value) external;

    function staked(address) external view returns (uint);

    function stakedBalance(StakedPoint memory _point, uint _ts) external pure returns (uint);

    function stakedBalanceOf(address _addr) external view returns (uint);

    function stakedBalanceOfAt(address _addr, uint _timestamp) external view returns (uint);

    function symbol() external view returns (string calldata);

    function totalSupply() external view returns (uint);

    function totalSupplyAt(uint _timestamp) external view returns (uint);

    function unstake(uint _value) external;

    function userClaimEpoch(address) external view returns (uint);

    function userPointEpoch(address) external view returns (uint);

    function userPointHistory(address, uint) external view returns (Point memory);

    function userSlopeChanges(address, uint) external view returns (int128);

    function userStakedEpoch(address) external view returns (uint);

    function userStakedHistory(address, uint) external view returns (StakedPoint memory);

    function userVestEpoch(address) external view returns (uint);

    function userVestHistory(address, uint) external view returns (Vest memory);

    function vest(address _addr, uint _amount) external;

    function vestWeeks() external view returns (uint);

    function withdraw() external;
}
