// SPDX-License-Identifier: MIT

pragma solidity ^0.4.24;

import "azimuth-solidity/contracts/Claims.sol";

contract ClaimsWrapper is Claims {
    constructor(Azimuth _azimuth)
    public Claims(_azimuth) {}
}
