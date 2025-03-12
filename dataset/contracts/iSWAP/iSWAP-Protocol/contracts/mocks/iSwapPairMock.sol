// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../dex/iSwapPair.sol";

contract SushiSwapPairMock is iSwapPair {
    constructor() public iSwapPair() {}
}