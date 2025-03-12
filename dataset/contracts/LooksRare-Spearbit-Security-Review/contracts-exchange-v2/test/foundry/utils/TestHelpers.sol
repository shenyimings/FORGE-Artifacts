// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "../../../lib/forge-std/src/Test.sol";

abstract contract TestHelpers is Test {
    modifier asPrankedUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }
}
