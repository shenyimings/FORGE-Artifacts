/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "./ERC1155Tradable.sol";

contract SuperfineNFT1155OpenSea is
    ERC1155Burnable,
    ERC1155Pausable,
    ERC1155Tradable
{
    using Strings for uint256;

    struct TokenInfo {
        uint256 tokenId;
        uint256 quantity;
        string uri;
    }

    uint256[] private _mintedTokenIds;
    mapping(uint256 => bool) private _isTokenIdMinted;

    constructor(
        string memory name,
        string memory symbol,
        string memory uri_,
        address proxyRegistryAddress
    ) ERC1155Tradable(name, symbol, uri_, proxyRegistryAddress) {}

    function _msgSender()
        internal
        view
        override(Context, ERC1155Tradable)
        returns (address)
    {
        return ERC1155Tradable._msgSender();
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view override(ERC1155, ERC1155Tradable) returns (bool isOperator) {
        return ERC1155Tradable.isApprovedForAll(owner, operator);
    }

    function uri(
        uint256 tokenId
    ) public view override(ERC1155, ERC1155Tradable) returns (string memory) {
        require(
            _isTokenIdMinted[tokenId] && _exists(tokenId),
            "SuperfineNFT1155OpenSea: URI query for non-existent token"
        );
        if (bytes(customUri[tokenId]).length > 0) return customUri[tokenId];
        return
            string(
                abi.encodePacked(
                    ERC1155Tradable.uri(tokenId),
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    function getOwnedTokens(
        address user,
        uint256 fromIndex,
        uint256 toIndex
    ) external view returns (TokenInfo[] memory) {
        // Default case
        if (_mintedTokenIds.length == 0) return new TokenInfo[](0);

        // Init query range
        uint256 lastIndex = toIndex;
        if (lastIndex >= _mintedTokenIds.length)
            lastIndex = _mintedTokenIds.length - 1;
        require(
            fromIndex <= lastIndex,
            "SuperfineNFT1155OpenSea: invalid query range"
        );

        // Get the number of owned ERC1155 NFTs
        uint256 numOwnedNFTs = 0;
        for (uint256 i = fromIndex; i <= lastIndex; i++)
            if (balanceOf(user, _mintedTokenIds[i]) > 0) numOwnedNFTs++;

        // Query all owned ERC1155 NFTs
        TokenInfo[] memory ownedNFTs = new TokenInfo[](numOwnedNFTs);
        uint256 nftCount = 0;
        for (uint256 j = fromIndex; j <= lastIndex; j++) {
            uint256 tokenId = _mintedTokenIds[j];
            if (balanceOf(user, tokenId) > 0) {
                ownedNFTs[nftCount] = TokenInfo(
                    tokenId,
                    balanceOf(user, tokenId),
                    uri(tokenId)
                );
                nftCount++;
            }
        }
        return ownedNFTs;
    }

    function setBaseTokenURI(string memory baseTokenURI_) external onlyOwner {
        _setURI(baseTokenURI_);
    }

    function burn(
        address account,
        uint256 tokenId,
        uint256 quantity
    ) public override {
        if (balanceOf(account, tokenId) == quantity) delete customUri[tokenId];
        ERC1155Burnable.burn(account, tokenId, quantity);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Pausable) {
        require(
            tokenIds.length == quantities.length,
            "SuperfineNFT1155OpenSea: lengths mismatch"
        );
        if (from == address(0))
            for (uint256 i = 0; i < tokenIds.length; i++)
                if (!_isTokenIdMinted[tokenIds[i]]) {
                    _isTokenIdMinted[tokenIds[i]] = true;
                    _mintedTokenIds.push(tokenIds[i]);
                }
        ERC1155Pausable._beforeTokenTransfer(
            operator,
            from,
            to,
            tokenIds,
            quantities,
            data
        );
    }
}
