// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

interface IMerkleProofMinter {
  struct Boundary {
    uint8 level;
    // bytes32 family;
    // uint8 persona;
    uint256 min;
    uint256 max;
  }

  event MerkleRootSet(address indexed account, bytes32 previous, bytes32 current);
  event BoundariesSet(address indexed account, uint256[] levels, Boundary[] boundaries);
  event MintedWithProof(address indexed account, bytes32[] proof, uint256 level, uint256 tokenId);
  event PersonaSet(address indexed account, uint8 level, uint8 persona);

  error InsufficientNpmBalanceError(uint256 minRequired);
  error InvalidBindingError(address account, uint256 boundTokenId);
  error InvalidPersonaError();
  error PersonaAlreadySetError();
  error PersonaMismatchError(uint8 expected, uint8 actual);
  error InvalidTokenIdError(uint256 tokenId);
  error TokenAlreadyMintedError(uint256 tokenId);
  error TokenIdOutOfBoundsError(uint256 min, uint256 max);
  error TokenAlreadySoulbound(uint256 tokenId);
  error TokenAlreadyClaimedError(uint8 level);
  error PreviousLevelMissingError();
  error InvalidProofError();
  error DuplicateRootError();
}
