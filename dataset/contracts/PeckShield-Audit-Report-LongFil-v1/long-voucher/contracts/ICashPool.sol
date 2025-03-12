// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICashPool {
    function redeem(uint256 voucherId, address receiver) external;
}
