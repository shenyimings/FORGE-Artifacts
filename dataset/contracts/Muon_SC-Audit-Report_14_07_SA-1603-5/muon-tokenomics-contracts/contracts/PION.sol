// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./Token.sol";

contract PION is Token {
    function initialize() public initializer {
        Token._initialize("PioneerNetwork", "PION");
    }
}
