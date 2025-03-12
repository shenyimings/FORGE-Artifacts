// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// aaaaaaaaaaaaaaaaaaaaaaam maaaaaaaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaaaaaaaa   maaaaaaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaaaaaaai   iaaaaaaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaaaaaai     iaaaaaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaaaaan       laaaaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaaaam         maaaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaaam   i   i   maaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaaai   m   m   iaaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaai   ma   am   iaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaaai   naa   aan   iaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaaaan   iaaa   aaai   naaaaaaaaaaaaaaa
// aaaaaaaaaaaaaam   iaaaa   aaaai   maaaaaaaaaaaaaa
// aaaaaaaaaaaaaa    aami     imaai   maaaaaaaaaaaaa
// aaaaaaaaaaaaai   mni         inm   iaaaaaaaaaaaaa
// aaaaaaaaaaaai   i    la   aii   i   iaaaaaaaaaaaa
// aaaaaaaaaaan      imaaa   aaami      naaaaaaaaaaa
// aaaaaaaaaam     imaaaaa   aaaaaai     maaaaaaaaaa
// aaaaaaaaam    naaaaaaaa   aaaaaaaani   maaaaaaaaa
// aaaaaaaaai   maaaaaaaaa   aaaaaaaaam    aaaaaaaaa
// aaaaaaaai   maaaaaaaaaa   aaaaaaaaaam   iaaaaaaaa
// aaaaaaal   laaaaaaaaali   ilaaaaaaaaan   iaaaaaaa
// aaaaaam   iaaaaaaami         imaaaaaaai   naaaaaa
// aaaaam   iaaaaaani   im   mi   inaaaaaai   maaaaa
// aaaaa    aaaami   inaaa   aaani   imaaaai   maaaa
// aaaai   maani   imaaaaa   aaaaami   inaam   iaaaa
// aaai   nmi   inaaaaaaaa   aaaaaaaani   imn   iaaa
// aan   ii   imaaaaaaaaaa   aaaaaaaaaami   ii   naa
// am      ilaaaaaaaaaaaaa   aaaaaaaaaaaaani      ma
// m       iiiiiiiiiiiiiii   iiiiiiiiiiiiiii       m
// i                                               i
// aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
// aaaaaaaaaaaaa  ANIMALIA TITANS NFT  aaaaaaaaaaaaa
// aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IERC2981.sol";

/// @custom:security-contact team@animalia.games
contract AnimaliaTitans is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Ownable,
    IERC2981
{
    uint16 public constant MAX_TOTAL_SUPPLY = 8700;

    uint8 public constant ROYALTY_PERCENTAGE = 2;

    address private _royaltyReceiver;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Animalia Titans", "ANIM") {
        _royaltyReceiver = owner();
    }

    function safeMint(string memory uri) public onlyOwner {
        require(
            super.totalSupply() <= MAX_TOTAL_SUPPLY,
            "Reached max token supply"
        );

        require(bytes(uri).length > 0, "URI must not be empty");

        // starts with tokenId 1
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        _safeMint(_msgSender(), tokenId);
        _setTokenURI(tokenId, uri);
    }

    // EIP2981 Royalties implementation
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address, uint256)
    {
        require(_exists(_tokenId), "ERC2981: token does not exist");
        uint256 royaltyAmount = (_salePrice * ROYALTY_PERCENTAGE) / 100;
        return (_royaltyReceiver, royaltyAmount);
    }

    function royaltyReceiver() external view returns (address) {
        return _royaltyReceiver;
    }

    function setRoyaltyReceiver(address newRoyaltyReceiver) external onlyOwner {
        require(
            newRoyaltyReceiver != _royaltyReceiver,
            "Same royalty receiver"
        );
        _royaltyReceiver = newRoyaltyReceiver;
    }

    // Disable renounceOwnership
    function renounceOwnership() public view override(Ownable) onlyOwner {
        revert("Cannot renounce ownership");
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
        override(ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
