// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IStrategy {
    function strategyReceive() external payable returns (uint256);

    function dETH() external view returns (address);

    function core() external view returns (address);
}
