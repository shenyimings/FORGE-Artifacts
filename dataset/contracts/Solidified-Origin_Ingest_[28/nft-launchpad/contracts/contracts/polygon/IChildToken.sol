// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;
}
