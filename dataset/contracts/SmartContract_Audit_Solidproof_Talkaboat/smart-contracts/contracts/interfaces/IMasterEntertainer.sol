// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

interface IMasterEntertainer {
    function updatePrice() external; 
    function getBalanceOf(address _user, uint256 _vesting) external view returns (uint256);
    function depositForUser(uint256 _pid, uint256 _amount, address _user) external;
}