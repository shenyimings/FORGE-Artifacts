// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Owners.sol";

contract OwnersMock {
    using Owners for Owners.AddressSet;

    Owners.AddressSet private _owners;

    function ownerOf(uint256 tokenId) public view returns (address) {
        return _owners.ownerOf(tokenId);
    }

    function mintBatch(address owner, uint256 from, uint256 count) public {
        _owners.mint(owner, from, count);
    }

    function transferTo(uint256 tokenId, address owner) public {
        _owners.overwrite(tokenId, owner);
    }
}
