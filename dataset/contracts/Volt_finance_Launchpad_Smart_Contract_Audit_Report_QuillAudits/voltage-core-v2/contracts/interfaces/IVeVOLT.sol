// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IVeVolt {
    function balanceOf(address owner, uint256 timestamp) external view returns (uint256);
}
