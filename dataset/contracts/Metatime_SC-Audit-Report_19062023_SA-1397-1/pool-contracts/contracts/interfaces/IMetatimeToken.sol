// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetatimeToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
}