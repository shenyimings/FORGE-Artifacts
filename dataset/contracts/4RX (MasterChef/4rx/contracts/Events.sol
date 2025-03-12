// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;


contract Events {
    event Deposit(address user, uint amount, uint8 stakeId, address uplinkAddress, uint uplinkStakeId);
    event Withdrawn(address user, uint amount);
    event ReInvest(address user, uint amount);
    event Exited(address user, uint stakeId, uint amount);
    event PoolDrawn(uint refPoolAmount, uint sponsorPoolAmount);
}
