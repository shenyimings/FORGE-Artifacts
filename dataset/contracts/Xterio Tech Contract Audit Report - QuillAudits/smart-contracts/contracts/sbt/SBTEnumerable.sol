//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./SBT.sol";

abstract contract SBTEnumerable is SBT, ERC721Enumerable {
    constructor(string memory name, string memory symbol) SBT(name, symbol) {}

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal pure override(ERC721, SBT) {
        SBT._transfer(from, to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(SBT, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
