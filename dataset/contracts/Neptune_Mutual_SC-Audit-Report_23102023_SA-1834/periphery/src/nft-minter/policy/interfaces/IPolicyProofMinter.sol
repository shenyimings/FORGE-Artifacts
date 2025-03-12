// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

interface IPolicyProofMinter {
  event SoulboundMinted(address indexed account, uint256 tokenId);
  event BoundarySet(address indexed triggeredBy, uint256 previousMin, uint256 min, uint256 previousMax, uint256 max);

  error InvalidBoundaryError(uint256 min, uint256 provided);
  error TokenAlreadyMintedError(uint256 tokenId);
  error TokenIdOutOfBoundsError(uint256 min, uint256 max);
  error TokenAlreadySoulbound(uint256 tokenId);
}
