// SPDX-License-Identifier: MIT

// This is a thin wrapper over Ecliptic.

pragma solidity ^0.4.24;

import "azimuth-solidity/contracts/Ecliptic.sol";

contract EclipticWrapper is Ecliptic {
    constructor(address _previous,
        Azimuth _azimuth,
        Polls _polls,
        Claims _claims)
    public Ecliptic(_previous, _azimuth, _polls, _claims) {}
}
