// SPDX-License-Identifier: MIT
// Copyright (C) 2021 Autonomous Worlds Ltd

pragma solidity ^0.7.6;

import "./IERC20.sol";

/**
 * @dev Interface for a contract that allows using HTLCs for ERC-20 tokens.
 */
interface IHTLCs
{

  /**
   * @dev Returns the hash used in HTLCs of the given data.
   */
  function hashData (bytes memory data) external pure returns (bytes20);

  /**
   * @dev Computes and returns the hash / ID of an HTLC corresponding
   * to the given data.
   */
  function getId (IERC20 token, address from, address to, uint256 value,
                  uint endtime, bytes20 hash) external pure returns (bytes32);

  /**
   * @dev Creates a new HTLC:  value tokens are removed from the message
   * sender's balance and "locked" into the HTLC.  They can be reclaimed
   * by the message sender at the endtime block time, or redeemed for the
   * receiver if the preimage of hash is provided.
   */
  function create (IERC20 token, address to, uint256 value,
                   uint endtime, bytes20 hash)
      external returns (bytes32);

  /**
   * @dev Refunds a HTLC that has timed out.  All data for the HTLC has to be
   * provided here again, and the contract will check that a HTLC with this
   * data exists (as well as that it is timed out).
   */
  function timeout (IERC20 token, address from, address to, uint256 value,
                    uint endtime, bytes20 hash) external;

  /**
   * @dev Redeems a HTLC with the preimage to the receiver.  The data
   * for the HTLC has to be passed in (the hash is computed from the preimage).
   */
  function redeem (IERC20 token, address from, address to, uint256 value,
                   uint endtime, bytes memory preimage) external;

  /** @dev Emitted when a new HTLC has been created.  */
  event Created (IERC20 token, address from, address to, uint256 value,
                 uint endtime, bytes20 hash, bytes32 id);

  /** @dev Emitted when a HTLC is timed out.  */
  event TimedOut (IERC20 token, address from, address to, uint256 value,
                  uint endtime, bytes20 hash, bytes32 id);

  /** @dev Emitted when a HTLC is redeemed.  */
  event Redeemed (IERC20 token, address from, address to, uint256 value,
                  uint endtime, bytes20 hash, bytes32 id);

}
