// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IWETH {
    function balanceOf(address user) external view returns (uint256);

    function approve(address to, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function deposit() external payable;

    function withdraw(uint256) external;
}
