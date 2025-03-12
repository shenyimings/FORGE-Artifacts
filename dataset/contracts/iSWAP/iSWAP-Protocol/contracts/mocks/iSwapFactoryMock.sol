// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../dex/iSwapFactory.sol";

contract iSwapFactoryMock is iSwapFactory {
    constructor(address _feeToSetter) public iSwapFactory(_feeToSetter) {}
}