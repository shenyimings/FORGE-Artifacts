// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface ITrusteeFeePool {
    function exit(address account) external;
    function enter(address account) external;
    function notifyReward(uint reward) external;
}