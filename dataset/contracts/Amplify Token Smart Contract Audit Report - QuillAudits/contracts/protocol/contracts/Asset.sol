// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./AssetStorage.sol";
import "./RiskModel.sol";

contract Asset is AssetStorage, RiskModel {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    event TokenizeAsset(uint256 indexed tokenId, string tokenHash,string tokenRating, uint256 value, string tokenURI, uint256 maturity, uint256 uploadedAt);

    constructor() ERC721("AmplifyAsset", "AAT") RiskModel(msg.sender) {}

    function tokenizeAsset(string memory tokenHash, string memory tokenRating, uint256 value, uint256 maturity, string memory tokenURI) external returns (uint256) {
        _tokenIds.increment();

        uint256 newAssetId = _tokenIds.current();
        _mint(msg.sender, newAssetId);

        _setTokenValue(newAssetId, value);  
        _setTokenMaturity(newAssetId, maturity);
        _setTokenHash(newAssetId, tokenHash);
        _setTokenRating(newAssetId, tokenRating);   
        _setTokenURI(newAssetId, tokenURI);
        _setTokenRedeemed(newAssetId, false);

        emit TokenizeAsset(newAssetId, tokenHash, tokenRating, value, tokenURI, maturity, block.timestamp);
        return newAssetId;
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }

    function markAsRedeemed(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can consume the asset");
        _setTokenRedeemed(tokenId, true);
    }
}
