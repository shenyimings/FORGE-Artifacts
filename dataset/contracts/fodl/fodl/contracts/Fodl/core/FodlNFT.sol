// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import '../connectors/interfaces/IResetAccountConnector.sol';

contract FodlNFT is ERC721, Ownable {
    bool private migrating;

    constructor(string memory name, string memory symbol) public ERC721(name, symbol) Ownable() {}

    function mint(address owner, uint256 nftId) external onlyOwner {
        _safeMint(owner, nftId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        ///@dev no need to reset account when migrating
        if (migrating) return;
        address foldingAccount = address(tokenId);
        IResetAccountConnector(foldingAccount).resetAccount(from, to, tokenId);
    }

    ///@notice FoldingAccount can change the tokenURI of its associated NFT
    function setTokenUri(string memory _tokenURI) external {
        uint256 tokenId = uint256(msg.sender);

        ///@dev _setTokenURI checks for existence of the tokenId
        _setTokenURI(tokenId, _tokenURI);
    }

    function migrateLegacyNFT(
        FodlNFT sourceNFT,
        uint256 fromIndex,
        uint256 toIndex
    ) external onlyOwner {
        migrating = true;
        uint256 count = sourceNFT.totalSupply();
        if (toIndex == 0 || toIndex > count) toIndex = count;
        for (uint256 i = fromIndex; i < toIndex; i++) {
            uint256 tokenId = sourceNFT.tokenByIndex(i);
            _safeMint(sourceNFT.ownerOf(tokenId), tokenId);
        }
        migrating = false;
    }
}
