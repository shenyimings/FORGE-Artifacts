// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMonNFT is IERC721{

    function getTokenAuthor(uint tokenId) external view returns(address);

    function getFeeCopyright(uint tokenId) external view returns(uint);
}