// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ITriBar {
    function enter(uint256 triAmount) external;

    function leave(uint256 xTriAmount) external;
}
