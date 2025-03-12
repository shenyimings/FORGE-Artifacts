// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface ILockedToken {
    function totalBalanceOf(address _holder) external view returns (uint256);
    function transferAll(address _to) external;
    function lockOf(address _holder) external view returns (uint256);
}
