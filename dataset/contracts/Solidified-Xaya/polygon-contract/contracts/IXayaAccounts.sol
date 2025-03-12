// SPDX-License-Identifier: MIT
// Copyright (C) 2021-2022 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./IXayaPolicy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Interface for the Xaya account registry contract.  This is the base
 * component of Xaya on any EVM chain, which keeps tracks of user accounts
 * and their moves.
 */
interface IXayaAccounts is IERC721
{

  /**
   * @dev Returns the address of the WCHI token used for payments
   * of fees and in moves.
   */
  function wchiToken () external returns (IERC20);

  /**
   * @dev Returns the address of the policy contract used.
   */
  function policy () external returns (IXayaPolicy);

  /**
   * @dev Returns the next nonce that should be used for a move with
   * the given token ID.  Nonces start at zero and count up for every move
   * sent.
   */
  function nextNonce (uint256 tokenId) external returns (uint256);

  /**
   * @dev Returns the unique token ID that corresponds to a given namespace
   * and name combination.  The token ID is determined deterministically from
   * namespace and name, so it does not matter if the account has been
   * registered already or not.
   */
  function tokenIdForName (string memory ns, string memory name)
      external pure returns (uint256);

  /**
   * @dev Returns the namespace and name for a token ID, which must exist.
   */
  function tokenIdToName (uint256)
      external view returns (string memory, string memory);

  /**
   * @dev Returns true if the given namespace/name combination exists.
   */
  function exists (string memory ns, string memory name)
      external view returns (bool);

  /**
   * @dev Returns true if the given token ID exists.
   */
  function exists (uint256 tokenId) external view returns (bool);

  /**
   * @dev Registers a new name.  The newly minted account NFT will be owned
   * by the caller.  Returns the token ID of the new account.
   */
  function register (string memory ns, string memory name)
      external returns (uint256);

  /**
   * @dev Sends a move with a given name, optionally attaching a WCHI payment
   * to the given receiver.  For no payment, amount and receiver should be
   * set to zero.
   *
   * If a nonce other than uint256.max is passed, then the move is valid
   * only if it matches exactly the account's next nonce.  The nonce used
   * is returned.
   */
  function move (string memory ns, string memory name, string memory mv,
                 uint256 nonce, uint256 amount, address receiver)
      external returns (uint256);

  /**
   * @dev Computes and returns the message to be signed for permitOperator.
   */
  function permitOperatorMessage (address operator)
      external view returns (bytes memory);

  /**
   * @dev Gives approval as per setApprovalForAll to an operator via a signed
   * permit message.  The owner to whose names permission is given is recovered
   * from the signature and returned.
   */
  function permitOperator (address operator, bytes memory signature)
      external returns (address);

  /**
   * @dev Emitted when a name is registered.
   */
  event Registration (string ns, string name, uint256 indexed tokenId,
                      address owner);

  /**
   * @dev Emitted when a move is sent.  If no payment is attached,
   * then the amount and address are zero.
   */
  event Move (string ns, string name, string mv,
              uint256 indexed tokenId,
              uint256 nonce, address mover,
              uint256 amount, address receiver);

}
