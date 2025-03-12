// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ILocker {
    function totalLock() external view returns (uint256);

    function lockOf(address _account) external view returns (uint256);

    function released(address _account) external view returns (uint256);

    function canUnlockAmount(address _account) external view returns (uint256);

    function lock(address _account, uint256 _amount) external;

    function unlock() external;
    
    function getStartReleaseBlock() external view returns (uint256);
}