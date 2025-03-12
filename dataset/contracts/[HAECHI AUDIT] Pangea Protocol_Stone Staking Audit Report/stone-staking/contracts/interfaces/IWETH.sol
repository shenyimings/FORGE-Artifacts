// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function depositTo(address to) external payable;

    function withdrawTo(address payable to, uint256 value) external;
}
