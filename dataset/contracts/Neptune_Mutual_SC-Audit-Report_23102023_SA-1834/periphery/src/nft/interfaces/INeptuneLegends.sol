// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

interface INeptuneLegends {
  struct MintInfo {
    address sendTo;
    uint256 id;
    bool soulbound;
  }

  event DefaultRoyaltySet(address indexed sender, address indexed receiver, uint96 feeNumerator);
  event DefaultRoyaltyDeleted(address indexed sender);
  event TokenRoyaltySet(address indexed sender, uint256 tokenId, address indexed receiver, uint96 feeNumerator);
  event TokenRoyaltyReset(address indexed sender, uint256 tokenId);
  event BaseUriSet(string previous, string current);
  event SoulBound(uint256 id);

  function mint(MintInfo calldata info) external;
  function mintMany(MintInfo[] calldata info) external;

  function _minted(uint256 id) external view returns (bool);
  function _soulbound(uint256 id) external view returns (bool);

  error SoulboundError(uint256 tokenId);
  error AlreadyBoundError(address account, uint256 boundTokenId, uint256 tokenId);
  error AlreadyMintedError(uint256 tokenId);
  error InvalidAmountError(uint256 valid, uint256 specified);
  error OperationNotSupportedError();
}
