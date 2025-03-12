// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract MockUSDC is MockERC20 {
    constructor() MockERC20("Mock USDC", "mUSDC", 6) {}
}
