// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./UniverseERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract UniverseERC721Core is UniverseERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    constructor(string memory _tokenName, string memory _tokenSymbol)
        UniverseERC721(_tokenName, _tokenSymbol)
    {}

    function batchMint(
        address receiver,
        string[] calldata tokenURIs,
        Fee[] memory fees
    ) external override returns (uint256[] memory) {
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
    ) external override returns (uint256[] memory) {
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
    ) external override returns (uint256[] memory) {
        require(tokenURIs.length <= 40, "Cannot mint more than 40");
        require(tokenURIs.length == fees.length, "Wrong fee config");

        uint256[] memory mintedTokenIds = new uint256[](tokenURIs.length);

        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = mint(receiver, tokenURIs[i], fees[i]);
            mintedTokenIds[i] = tokenId;
        }

        return mintedTokenIds;
    }

    function mint(
        address receiver,
        string memory tokenURI,
        Fee[] memory fees
    ) public override returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(receiver, newItemId);
        _setTokenURI(newItemId, tokenURI);
        if (fees.length > 0) {
            _registerFees(newItemId, fees);
            // The ERC2981 standard supports only one split, so we set the first value
            _setTokenRoyalty(newItemId, fees[0].recipient, fees[0].value);
        }
        // We use tx.origin to set the creator, as there are cases when a contract can call this funciton
        creatorOf[newItemId] = tx.origin;

        emit UniverseERC721TokenMinted(newItemId, tokenURI, receiver, block.timestamp);
        return newItemId;
    }
}
