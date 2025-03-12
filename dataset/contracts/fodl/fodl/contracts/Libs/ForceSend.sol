// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

/**
 * Contract made to force some impersonated accounts to receive ETH,
 * e.g. WBTC Controller
 */
contract ForceSend {
    constructor(address payable to) public payable {
        selfdestruct(to);
    }
}
