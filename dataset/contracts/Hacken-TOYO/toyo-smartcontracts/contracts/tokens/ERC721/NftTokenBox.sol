// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./NftTokenBase.sol";

contract NftTokenBox is NftTokenBase
{
    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }
}
