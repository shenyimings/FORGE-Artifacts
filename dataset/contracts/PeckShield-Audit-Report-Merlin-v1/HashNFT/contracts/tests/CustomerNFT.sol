// contracts/NFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CustomerNFT is ERC721Enumerable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _counter;

    string public baseURI;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
    }

    function mint(address to) public returns(uint256 tokenId) {
        tokenId = _counter.current();
        _safeMint(to, tokenId);
        _counter.increment();
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256) public view virtual override returns (string memory) {
        return baseURI;
    }

    /**
     * @dev Set base URI for computing {tokenURI}.
     */
    function setBaseURI(string calldata _baseuri) external {
        baseURI = _baseuri;
    }

}