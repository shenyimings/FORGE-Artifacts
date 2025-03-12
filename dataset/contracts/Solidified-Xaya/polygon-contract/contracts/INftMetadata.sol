// SPDX-License-Identifier: MIT
// Copyright (C) 2021 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

/**
 * @dev Interface for a contract that can generate the NFT metadata for
 * a given namespace/name combination.
 */
interface INftMetadata
{

  /**
   * @dev Constructs the NFT image as SVG data URL.
   */
  function buildSvgImage (string memory ns, string memory name)
      external view returns (string memory);

  /**
   * @dev Constructs the metadata JSON for a given name and returns it
   * as data URI.
   */
  function buildMetadataJson (string memory ns, string memory name)
      external view returns (string memory);

  /**
   * @dev Constructs the full metadata URI for a given name.
   */
  function tokenUriForName (string memory ns, string memory name)
      external view returns (string memory);

  /**
   * @dev Returns a link to the contract-level metadata.
   */
  function contractUri () external view returns (string memory);

}
