// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IMasterChefV2 {
    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;

    function emergencyWithdraw(uint256 pid, address to) external;

    function userInfo(uint256 pid, address user) external view returns (uint256, uint256);

    function lpToken(uint256 pid) external view returns (address);
}
