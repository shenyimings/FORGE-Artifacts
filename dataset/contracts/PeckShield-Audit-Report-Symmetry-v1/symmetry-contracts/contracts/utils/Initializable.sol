// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Initializable {
    bool public initialized;

    modifier onlyInitializeOnce() {
        require(!initialized, "Initializable: already initialized");
        initialized = true;
        _;
    }
}
