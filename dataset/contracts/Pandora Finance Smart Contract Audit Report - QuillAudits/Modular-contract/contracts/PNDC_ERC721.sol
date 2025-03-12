// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Libraries/LibShare.sol";

contract PNDC_ERC721 is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    event RoyaltiesSetForTokenId(
        uint256 tokenId,
        LibShare.Share[] royalties
    );

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => LibShare.Share[]) public royaltiesByTokenId;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function safeMint(
        address to,
        string memory uri,
        LibShare.Share[] memory royalties
    ) external returns(uint256){
        uint256 tokenId = _tokenIdCounter.current();
        _setRoyaltiesByTokenId(tokenId, royalties);
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    function batchMint(
        uint256 _totalNft,
        string[] memory _uri,
        LibShare.Share[][] memory royaltiesSet
    ) external {
        require(_totalNft <= 15, "Minting more than 15 Nfts are not allowe");
        require(
            _totalNft == _uri.length,
            "uri array length should be equal to _totalNFT"
        );
        for (uint256 i = 0; i < _totalNft; i++) {
            this.safeMint(msg.sender, _uri[i], royaltiesSet[i]);
        }
    }

    function burn(uint256 _tokenId) external {
        require(msg.sender == ownerOf(_tokenId));

        _burn(_tokenId);
    }

    function _setRoyaltiesByTokenId(
        uint256 _tokenId,
        LibShare.Share[] memory royalties
    ) internal {
        require(royalties.length <= 10);
        delete royaltiesByTokenId[_tokenId];
        uint256 sumRoyalties = 0;
        for (uint256 i = 0; i < royalties.length; i++) {
            require(
                royalties[i].account != address(0x0),
                "Royalty recipient should be present"
            );
            require(royalties[i].value != 0, "Royalty value should be > 0");
            royaltiesByTokenId[_tokenId].push(royalties[i]);
            sumRoyalties += royalties[i].value;
        }
        require(sumRoyalties < 10000, "Sum of Royalties > 100%");

        emit RoyaltiesSetForTokenId(_tokenId, royalties);
    }

    function getRoyalties(uint256 _tokenId)
        external
        view
        returns (LibShare.Share[] memory)
    {
        return royaltiesByTokenId[_tokenId];
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}