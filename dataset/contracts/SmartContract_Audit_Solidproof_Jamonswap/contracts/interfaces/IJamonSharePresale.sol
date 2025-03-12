// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IJamonSharePresale {
    function status() external view returns (uint256 round, uint256 rate);
}
