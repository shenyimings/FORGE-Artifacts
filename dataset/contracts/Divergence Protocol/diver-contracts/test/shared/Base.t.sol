// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Test } from "@std/Test.sol";
import { console2 } from "@std/console2.sol";

abstract contract BaseTest is Test {
    function setUp() public virtual {
        console2.log(">>>Divergence Protocol Solidity Test<<<");
        vm.createSelectFork("localhost");
    }
}
