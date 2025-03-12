// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.6;

interface IxECP {
    function mintReward(address _user, uint256 _amount) external;
    function setMinter(address _minter) external;
}