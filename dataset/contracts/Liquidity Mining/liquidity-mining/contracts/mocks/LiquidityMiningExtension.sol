// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../LiquidityMining.sol";

contract LiquidityMiningExtension is LiquidityMining {
    function test() public pure returns (string memory) {
        return "test";
    }
}
