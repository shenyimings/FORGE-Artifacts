// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function transfer(address to, uint256 value) external returns (bool);
}
