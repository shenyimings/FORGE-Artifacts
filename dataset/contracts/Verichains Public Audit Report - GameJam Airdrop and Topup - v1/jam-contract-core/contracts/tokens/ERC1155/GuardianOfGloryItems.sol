/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.6;

import "./SuperfineNFT1155.sol";

contract GuardianOfGloryItems is SuperfineNFT1155 {
    constructor(
        address owner,
        address minter,
        string memory uri
    ) SuperfineNFT1155(uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(MINTER_ROLE, minter);
    }
}
