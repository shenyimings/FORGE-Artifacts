// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILPLocker {
    function initialize(uint256 _initial_unlock_ts) external;
    function withdrawLP(address _LPaddress, uint256 _amount, address _to) external;
    function updateLock(uint256 _newUnlockTimestamp) external;
    function getInfoLP(address _LPaddress) external view returns (address locker_address, uint256 LPbalance, uint256 unlock_timestamp, bool unlocked);
    event Initialized(address indexed _token, uint256 _initial_unlock_ts);
    event LPWithdrawn(address indexed _LPaddress, uint256 _amount, address indexed _to);
    event LPLockUpdated(uint256 _oldUnlockTimestamp, uint256 _newUnlockTimestamp);
}