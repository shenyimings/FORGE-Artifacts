// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface CTokenInterface {
    function balanceOf(address owner) external view returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function borrowIndex() external view returns (uint);
    function totalSupply() external view returns (uint);
    function totalBorrows() external view returns (uint);
}
