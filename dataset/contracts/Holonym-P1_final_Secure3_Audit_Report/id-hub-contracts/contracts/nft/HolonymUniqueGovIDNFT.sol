// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HolonymUniqueGovIDNFT is ERC721, Ownable {
    constructor() ERC721("HolonymUniqueGovID", "HUGI") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://nft.holonym.io/nft-img/";
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal override
    {
        revert("Cannot transfer this type of token");
    }
}
