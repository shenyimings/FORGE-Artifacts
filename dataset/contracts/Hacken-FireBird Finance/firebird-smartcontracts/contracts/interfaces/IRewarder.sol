// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRewarder {
    function onHopeReward(uint256 pid, address user, address recipient, uint256 hopeAmount, uint256 newLpAmount) external;

    function pendingTokens(uint256 pid, address user, uint256 hopeAmount) external view returns (address[] memory, uint256[] memory);
}
