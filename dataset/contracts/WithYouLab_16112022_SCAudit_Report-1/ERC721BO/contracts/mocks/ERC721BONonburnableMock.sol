// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/ERC721BONonburnable.sol";

contract ERC721BONonburnableMock is ERC721BONonburnable {

    constructor(string memory name, string memory symbol) ERC721BO(name, symbol) {
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    function mint(address to, uint256 quantity) external {
        _mint(to, quantity);
    }

    function safeMint(address to, uint256 quantity) external {
        _safeMint(to, quantity);
    }

    function safeReMint(address to, uint256 tokenId) external {
        _safeReMint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}
