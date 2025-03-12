// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ITokenLocker {
    function startReleaseTime() external view returns (uint256);

    function endReleaseTime() external view returns (uint256);

    function totalLock() external view returns (uint256);

    function totalReleased() external view returns (uint256);

    function lockOf(address _account) external view returns (uint256);

    function released(address _account) external view returns (uint256);

    function canUnlockAmount(address _account) external view returns (uint256);

    function lock(address _account, uint256 _amount, bytes32 _tx) external;

    function claimUnlocked() external;

    function claimUnlockedFor(address _account) external;
}
