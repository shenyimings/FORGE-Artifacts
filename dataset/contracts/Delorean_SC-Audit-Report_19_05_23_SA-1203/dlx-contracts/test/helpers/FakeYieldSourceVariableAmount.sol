//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { FakeYieldSource, CallbackFakeToken } from "./FakeYieldSource.sol";
import { IFakeToken, FakeToken } from "./FakeToken.sol";

contract FakeYieldSourceVariableAmount is FakeYieldSource {

    constructor(uint256 yieldPerSecond_) FakeYieldSource(yieldPerSecond_) {
    }

    function amountPending() external override virtual view returns (uint256) {
        uint256 start = lastHarvestBlockNumber[address(this)] == 0
            ? startBlockNumber
            : lastHarvestBlockNumber[address(this)];
        uint256 deltaBlocks = block.number - start;
        uint256 total = _generatorToken.balanceOf(address(this)) * deltaBlocks * yieldPerSecond;
        return total + pending[address(this)];
    }
}
