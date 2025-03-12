// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasicERC721 {
    function mint(address to, uint256 tokenId) external;

    function mintBatch(address to, uint256[] calldata tokenId) external;

    function setURI(string calldata newBaseURI) external;
}
