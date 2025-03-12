// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract TestHelper is Test {
    
    function _moveBlock(uint256 n) internal {
        // NOTE: On Avalanche a block is emitted each two seconds on average
        vm.warp(block.timestamp + 2*n);
        vm.roll(block.number + n);
    }
}