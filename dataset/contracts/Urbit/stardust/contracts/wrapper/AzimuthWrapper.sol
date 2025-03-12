// SPDX-License-Identifier: MIT

// This is a thin wrapper over the underlying Azimuth code. Why is it necessary? Why not just use
// an ABI or an interface? The Treasury contract does use a simple interface. This works fine for
// mainnet, and for networks where Azimuth has already been deployed (and we know the address where
// it's deployed). However, for testing in a development environment, we first need to be able to
// deploy a copy of Azimuth to be able to interact with it. Azimuth was implemented using an older
// version of solidity. Modernizing it would require making many changes, including to the upstream
// libraries that it depends on, and would be self-defeating since this library would no longer work
// with previously deployed versions of Azimuth. Instead, we use this wrapper to compile it using
// legacy solidity and deploy it in the development environment. The wrapper is also useful so that
// we can pull the library directly from npm/github rather than copying it into this repository (and
// the truffle migrations/test files aren't able to do that, we can only read the imported version
// here).

pragma solidity ^0.4.24;

import "azimuth-solidity/contracts/Azimuth.sol";

contract AzimuthWrapper is Azimuth {
    constructor()
    public Azimuth() {}
}
