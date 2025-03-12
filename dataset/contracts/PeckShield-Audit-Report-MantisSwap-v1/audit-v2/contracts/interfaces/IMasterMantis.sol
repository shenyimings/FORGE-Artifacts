// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IMasterMantis {
    function deposit(address _user, uint256 _pid, uint256 _amount) external;

    function withdrawFor(address recipient, uint256 _pid, uint256 _amount) external;

    function getTokenPid(address token) external view returns (uint256);

    function updateRewardFactor(address _user) external;

    function resetVote(address user) external;
}