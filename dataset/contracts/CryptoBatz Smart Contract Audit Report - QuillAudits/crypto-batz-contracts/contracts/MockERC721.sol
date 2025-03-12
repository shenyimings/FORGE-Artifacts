// SPDX-License-Identifier: None
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract MockERC721 is Ownable, ERC721Enumerable {
    using SafeMath for uint256;

    constructor() ERC721("NFT", "NFT") { }

    function mint(uint256 numTokens) public {

        uint256 newTokenId = totalSupply();
        for(uint i = 0; i < numTokens; i++) {
            newTokenId = newTokenId + 1;
            _safeMint(msg.sender, newTokenId);
        }
    }

    function mintSpecific(uint256 tokenId) public {
      _safeMint(msg.sender, tokenId);
    }
}
