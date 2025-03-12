// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MockERC721 is ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    /**
     * @dev Initializes ERC721 token
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /**
     * @dev Creates a new token for `to`. Public for any test to call.
     *
     * See {ERC721-_mint}.
     */
    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _tokenIdTracker.current();
        _mint(to, uint256(uint160(address(this))) + tokenId);
        _tokenIdTracker.increment();
    }


    /**
     * @dev Creates a new token for `to`. Public for any test to call.
     *
     * See {ERC721-_mint}.
     */
    function mintId(uint256 id, address to) external returns (uint256 tokenId) {
        _mint(to, id);
        _tokenIdTracker.increment();

        return id;
    }

    /**
     * @dev Burn the given token, can be called by anyone
     */
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}

contract MockERC721Metadata is MockERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    mapping(uint256 => string) public tokenURIs;

    constructor(string memory name, string memory symbol) MockERC721(name, symbol) {}

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return tokenURIs[tokenId];
    }

    /**
     * @dev Creates a new token for `to`. Public for any test to call.
     *
     * See {ERC721-_mint}.
     */
    function mint(address to, string memory tokenUri) external returns (uint256 tokenId) {
        tokenId = _tokenIdTracker.current();
        _mint(to, tokenId);
        _tokenIdTracker.increment();
        _setTokenURI(tokenId, tokenUri);
    }

    function _setTokenURI(uint256 tokenId, string memory tokenUri) internal {
        tokenURIs[tokenId] = tokenUri;
    }
}
