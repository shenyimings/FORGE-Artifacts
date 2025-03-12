// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MorphoStorage} from "src/MorphoStorage.sol";

import "./ForkTest.sol";

contract InternalTest is ForkTest, MorphoStorage {
    using TestConfigLib for TestConfig;

    constructor() MorphoStorage(_initConfig().getAddressesProvider(), 0) {}
}
