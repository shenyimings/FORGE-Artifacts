// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../interfaces/IVotingWeightSource.sol";
import "hardhat/console.sol";

// Tester contract for getting voting weights from external KAPSource
contract VotingWeightSourceTester is IVotingWeightSource {
    uint256 private val;

    constructor(uint256 _val) {
        val = _val;
    }

    function setVal(uint256 _val) external {
        val = _val;
    }

    function votingWeight(address) external view returns (uint256) {
        // console.log("weightKAP returned", val, "for", _voter);
        return val;
    }
}
