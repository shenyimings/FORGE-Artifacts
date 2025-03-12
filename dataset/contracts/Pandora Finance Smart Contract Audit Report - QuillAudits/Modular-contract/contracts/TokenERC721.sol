// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Libraries/LibShare.sol";

contract TokenERC721 is ERC721Enumerable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    struct RoyaltiesSet {
        bool set;
        LibShare.Share[] royalties;
    }

    event RoyaltiesSetForCollection(LibShare.Share[] royalties);
    event RoyaltiesSetForTokenId(uint256 tokenId, LibShare.Share[] royalties);

    Counters.Counter private _tokenIdCounter;

    LibShare.Share[] public collectionRoyalties;
    mapping(uint256 => RoyaltiesSet) public royaltiesByTokenId;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function safeMint(
        address to,
        string memory uri,
        RoyaltiesSet memory royaltiesSet
    ) public onlyOwner returns(uint256){
        uint256 tokenId = _tokenIdCounter.current();
        setRoyaltiesByTokenId(tokenId, royaltiesSet);
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    function batchMint(
        uint256 _totalNft,
        string[] memory _uri,
        RoyaltiesSet memory royaltiesSet
    ) external onlyOwner{
        require(_totalNft <= 15, "Minting more than 15 Nfts are not allowe");
        require(
            _totalNft == _uri.length,
            "uri array length should be equal to _totalNFT"
        );
        for (uint256 i = 0; i < _totalNft; i++) {
            safeMint(msg.sender, _uri[i], royaltiesSet);
        }
    }

    function burn(uint256 _tokenId) public {
        require(msg.sender == ownerOf(_tokenId));

        _burn(_tokenId);
    }

    function setRoyaltiesByTokenId(
        uint256 _tokenId,
        RoyaltiesSet memory royaltiesSet
    ) public onlyOwner {
        delete royaltiesByTokenId[_tokenId];
        royaltiesByTokenId[_tokenId].set = royaltiesSet.set;
        _setRoyaltiesArray(royaltiesByTokenId[_tokenId].royalties, royaltiesSet.royalties);
        emit RoyaltiesSetForTokenId(_tokenId, royaltiesSet.royalties);
    }

    function setRoyaltiesForCollection(LibShare.Share[] memory royalties)
        public
        onlyOwner
    {
        delete collectionRoyalties;
        _setRoyaltiesArray(collectionRoyalties, royalties);
        emit RoyaltiesSetForCollection(royalties);
    }

    function getRoyalties(uint256 _tokenId)
        external
        view
        returns (LibShare.Share[] memory)
    {
        if (royaltiesByTokenId[_tokenId].set) {
            return royaltiesByTokenId[_tokenId].royalties;
        }
        return collectionRoyalties;
    }

    function _setRoyaltiesArray(
        LibShare.Share[] storage royaltiesArr,
        LibShare.Share[] memory royalties
    ) internal {
        require(royalties.length <= 10);
        uint256 sumRoyalties = 0;
        for (uint256 i = 0; i < royalties.length; i++) {
            require(
                royalties[i].account != address(0x0),
                "Royalty recipient should be present"
            );
            require(royalties[i].value != 0, "Royalty value should be > 0");
            royaltiesArr.push(royalties[i]);
            sumRoyalties += royalties[i].value;
        }
        require(sumRoyalties < 10000, "Sum of Royalties > 100%");
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
