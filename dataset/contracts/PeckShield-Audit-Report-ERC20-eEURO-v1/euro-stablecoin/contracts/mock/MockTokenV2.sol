// SPDX-License-Identifier: MIT
// Used for testing upgradability
pragma solidity ^0.8.4;

import "../EUROStablecoin.sol";

contract MockTokenV2 is EUROStablecoin {
    bool public isThisNewVersion = true;
}
