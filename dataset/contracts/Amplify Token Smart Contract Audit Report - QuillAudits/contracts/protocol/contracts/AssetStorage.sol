// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

abstract contract AssetStorage is ERC721URIStorage {

    mapping(uint256 => uint256) private _tokensValue;
    mapping(uint256 => string) private _tokensHash;
    mapping(uint256 => string) private _tokensRating;
    mapping(uint256 => uint256) private _tokensMaturity;
    mapping(uint256 => bool) private _tokensRedeemed;

    function _setTokenHash(uint256 _tokenId, string memory _hash) internal {
        _tokensHash[_tokenId] = _hash;
    }
    function getTokenHash(uint256 _tokenId) public view returns (string memory) {
        return _tokensHash[_tokenId];
    }
    function _setTokenRating(uint256 _tokenId, string memory _rating) internal {
        _tokensRating[_tokenId] = _rating;
    }
    function getTokenRating(uint256 _tokenId) public view returns (string memory) {
        return _tokensRating[_tokenId];
    }
    function _setTokenMaturity(uint256 _tokenId, uint256 _maturity) internal {
        _tokensMaturity[_tokenId] = _maturity;
    }
    function getTokenMaturity(uint256 _tokenId) public view returns (uint256) {
        return _tokensMaturity[_tokenId];
    }

     function _setTokenValue(uint256 _tokenId, uint256 _value) internal {
        _tokensValue[_tokenId] = _value;
    }
    function getTokenValue(uint256 _tokenId) public view returns (uint256) {
        return _tokensValue[_tokenId];
    }

    function _setTokenRedeemed(uint256 _tokenId, bool status) internal {
        _tokensRedeemed[_tokenId] = status;
    }
    function getRedeemStatus(uint256 _tokenId) public view returns (bool) {
        return _tokensRedeemed[_tokenId];
    }
}