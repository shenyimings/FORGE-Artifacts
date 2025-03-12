// SPDX-License-Identifier: MIT
// Used for testing upgradability
pragma solidity ^0.8.4;

import "../EUROe.sol";

contract MockTokenV2 is EUROe {
    bool public isThisNewVersion = true;
}
