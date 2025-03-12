// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ISmartChef {
    function stakedToken() external view returns (IERC20Upgradeable);

    function rewardToken() external view returns (IERC20Upgradeable);

    // Deposit '_amount' of stakedToken tokens
    function deposit(uint256 _amount) external;

    // Withdraw '_amount' of stakedToken and all pending rewardToken tokens
    function withdraw(uint256 _amount) external;
}
