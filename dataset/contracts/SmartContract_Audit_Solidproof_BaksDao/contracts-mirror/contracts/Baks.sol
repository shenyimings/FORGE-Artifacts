// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./BaseToken.sol";

contract Baks is BaseToken {
    constructor(address _minter) BaseToken("Baks", "BAKS", 18, _minter) {}
}
