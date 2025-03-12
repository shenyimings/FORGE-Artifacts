// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICurve {
    function viewDeposit(uint256 deposit) external view returns (uint256, uint256[] memory);
    function deposit(uint256 deposit, uint256 deadline) external;
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function derivatives(uint256) external view returns (address);
}
