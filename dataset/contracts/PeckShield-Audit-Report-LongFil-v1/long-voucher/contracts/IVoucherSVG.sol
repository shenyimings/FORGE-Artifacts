// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IVoucherSVG {
  
  function generateSVG(uint256 tokenId_) external view returns (bytes memory);

}