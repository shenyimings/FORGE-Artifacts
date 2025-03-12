// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.6.12;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}
