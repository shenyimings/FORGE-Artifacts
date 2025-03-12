// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { MockERC20 } from "./MockERC20.sol";

contract MockTranche is MockERC20 {
    address public bond;

    function setBond(address b) external {
        bond = b;
    }
}
