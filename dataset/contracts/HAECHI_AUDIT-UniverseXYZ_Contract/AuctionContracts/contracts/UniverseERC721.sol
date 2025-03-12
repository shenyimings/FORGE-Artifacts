// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721Consumable.sol";
import "./HasSecondarySaleFees.sol";
import "./ERC2981Royalties.sol";

contract UniverseERC721 is ERC721Enumerable, ERC721URIStorage, ERC721Consumable, Ownable, HasSecondarySaleFees, ERC2981Royalties {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    // Mapping from token ID to creator address;
    mapping(uint256 => address) public creatorOf;

    // Mapping from token ID to torrent magnet links
    mapping (uint256 => string) public torrentMagnetLinkOf;

    event UniverseERC721TokenMinted(
        uint256 tokenId,
        string tokenURI,
        address receiver,
        uint256 time
    );

    modifier onlyCreator(uint256 tokenId) {
        require(msg.sender == creatorOf[tokenId], "Not called from the creator");
        _;
    }

    constructor(string memory _tokenName, string memory _tokenSymbol)
        ERC721(_tokenName, _tokenSymbol)
    {}

    function batchMint(
        address receiver,
        string[] calldata tokenURIs,
        Fee[] memory fees
    ) external virtual onlyOwner returns (uint256[] memory) {
        require(tokenURIs.length <= 40, "Cannot mint more than 40");

        uint256[] memory mintedTokenIds = new uint256[](tokenURIs.length);

        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = mint(receiver, tokenURIs[i], fees);
            mintedTokenIds[i] = tokenId;
        }

        return mintedTokenIds;
    }

    function batchMintMultipleReceivers(
        address[] calldata receivers,
        string[] calldata tokenURIs,
        Fee[] memory fees
    ) external virtual onlyOwner returns (uint256[] memory) {
        require(tokenURIs.length <= 40, "Cannot mint more than 40");
        require(receivers.length == tokenURIs.length, "Wrong config");

        uint256[] memory mintedTokenIds = new uint256[](tokenURIs.length);

        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = mint(receivers[i], tokenURIs[i], fees);
            mintedTokenIds[i] = tokenId;
        }

        return mintedTokenIds;
    }

    function batchMintWithDifferentFees(
        address receiver,
        string[] calldata tokenURIs,
        Fee[][] memory fees
    ) external virtual onlyOwner returns (uint256[] memory) {
        require(tokenURIs.length <= 40, "Cannot mint more than 40");
        require(tokenURIs.length == fees.length, "Wrong fee config");

        uint256[] memory mintedTokenIds = new uint256[](tokenURIs.length);

        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = mint(receiver, tokenURIs[i], fees[i]);
            mintedTokenIds[i] = tokenId;
        }

        return mintedTokenIds;
    }

    function updateTorrentMagnetLink(uint256 _tokenId, string memory _torrentMagnetLink)
        external
        virtual
        onlyCreator(_tokenId)
        returns (string memory)
    {
        torrentMagnetLinkOf[_tokenId] = _torrentMagnetLink;

        return _torrentMagnetLink;
    }

    function ownedTokens(address ownerAddress) external view returns (uint256[] memory) {
        uint256 tokenBalance = balanceOf(ownerAddress);
        uint256[] memory tokens = new uint256[](tokenBalance);

        for (uint256 i = 0; i < tokenBalance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(ownerAddress, i);
            tokens[i] = tokenId;
        }

        return tokens;
    }

    function mint(
        address receiver,
        string memory newTokenURI,
        Fee[] memory fees
    ) public virtual onlyOwner returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(receiver, newItemId);
        _setTokenURI(newItemId, newTokenURI);
        if (fees.length > 0) {
            _registerFees(newItemId, fees);
            // The ERC2981 standard supports only one split, so we set the first value
            _setTokenRoyalty(newItemId, fees[0].recipient, fees[0].value);
        }
        // We use tx.origin to set the creator, as there are cases when a contract can call this funciton
        creatorOf[newItemId] = tx.origin;

        emit UniverseERC721TokenMinted(newItemId, newTokenURI, receiver, block.timestamp);
        return newItemId;
    }

    function _registerFees(uint256 _tokenId, Fee[] memory _fees) internal {
        require(_fees.length <= 5, "No more than 5 recipients");
        address[] memory recipients = new address[](_fees.length);
        uint256[] memory bps = new uint256[](_fees.length);
        uint256 sum = 0;
        for (uint256 i = 0; i < _fees.length; i++) {
            require(_fees[i].recipient != address(0x0), "Recipient should be present");
            require(_fees[i].value != 0, "Fee value should be positive");
            sum = sum + _fees[i].value;
            fees[_tokenId].push(_fees[i]);
            recipients[i] = _fees[i].recipient;
            bps[i] = _fees[i].value;
        }
        require(sum <= 3000, "Fee should be less than 30%");
        if (_fees.length > 0) {
            emit SecondarySaleFees(_tokenId, recipients, bps);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Storage, ERC721, ERC721Enumerable, ERC721Consumable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorage, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721URIStorage, ERC721) {
        return super._burn(tokenId);
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721Enumerable, ERC721, ERC721Consumable) {
        return super._beforeTokenTransfer(from, to, tokenId);
    }
}
