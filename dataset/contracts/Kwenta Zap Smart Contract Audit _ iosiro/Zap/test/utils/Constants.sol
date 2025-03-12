// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

/// @title Contract for defining constants used in testing
/// @author JaredBorders (jaredborders@pm.me)
contract Constants {
    uint256 public constant BASE_BLOCK_NUMBER = 8_163_300;

    address public constant ACTOR = address(0xAC7AC7AC7);

    uint256 public constant INITIAL_MINT = type(uint256).max / 10;

    uint256 public constant AMOUNT = 1000;
}
