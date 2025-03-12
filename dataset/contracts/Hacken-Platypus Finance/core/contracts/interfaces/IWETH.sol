// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

interface IWETH {
    function deposit() external payable;

    function balanceOf(address account) external returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}
