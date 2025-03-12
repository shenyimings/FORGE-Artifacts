// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../Asset/Asset.sol";

contract AssetHarness is Asset {
    constructor() Asset() {
        isAssetsFactory = false;
    }
}