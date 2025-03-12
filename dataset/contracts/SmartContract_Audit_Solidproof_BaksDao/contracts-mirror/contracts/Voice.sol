// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./BaseToken.sol";

contract Voice is BaseToken {
    constructor(address minter) BaseToken("BaksDAO Voice", "BDV", 18, minter) {}
}
