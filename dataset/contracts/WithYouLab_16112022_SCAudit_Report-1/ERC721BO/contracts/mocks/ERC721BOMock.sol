// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC721BO.sol";

contract ERC721BOMock is ERC721BO {
    string private _uri;

    constructor(string memory name, string memory symbol, string memory uri) ERC721BO(name, symbol) {
        _uri = uri;
    }

    function baseURI() external view returns (string memory) {
        return _baseURI();
    }

    function _baseURI() internal view override returns (string memory) {
        return bytes(_uri).length == 0 ? super._baseURI() : _uri;
    }

    function setBaseURI(string memory uri) external {
        _uri = uri;
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

    function safeMint(address to, uint256 quantity, bytes memory _data) external {
        _safeMint(to, quantity, _data);
    }

    function safeReMint(address to, uint256 tokenId) external {
        _safeReMint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}
