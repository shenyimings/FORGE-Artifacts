// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

library LibShare {
    // Defines the share of royalties for the address
    struct Share {
        address payable account;
        uint96 value;
    }
}