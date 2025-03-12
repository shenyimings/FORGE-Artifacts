// SPDX-License-Identifier: MIT
// Copyright (C) 2021-2022 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./IXayaPolicy.sol";

/**
 * @dev An implementation of IXayaPolicy for use in unit tests, with
 * very simple behaviour that allows to exercise all possible cases.
 *
 * THIS CONTRACT IS MEANT ONLY FOR TESTING, AND SHOULD NOT BE DEPLOYED
 * OR USED IN PRODUCTION!
 */
contract TestPolicy is IXayaPolicy
{

  /** @dev The fee receiver address.  */
  address public override immutable feeReceiver;

  /**
   * @dev Constructs the contract, setting the policy receiver initially
   * to the deploying account.
   */
  constructor ()
  {
    feeReceiver = msg.sender;
  }

  /**
   * @dev Checks if a name registration is valid.  In this policy, they are
   * valid if the namespace is non-empty.  The fee is 100 units per byte
   * in the name normally, except zero for names with exactly one byte.
   */
  function checkRegistration (string memory ns, string memory name)
      external pure override returns (uint256)
  {
    require (bytes (ns).length > 0, "namespace must not be empty");
    bytes memory data = bytes (name);
    return data.length == 1 ? 0 : 100 * data.length;
  }

  /**
   * @dev Checks if a move is valid.  In this policy, a move is valid if
   * it is not empty.  The fee is one unit per byte in the move data,
   * except for names with exactly one byte, where it is zero.
   */
  function checkMove (string memory, string memory mv)
      external pure override returns (uint256)
  {
    bytes memory data = bytes (mv);
    require (data.length > 0, "move data must not be empty");
    return data.length == 1 ? 0 : data.length;
  }

  /**
   * @dev Returns the metadata URI for a name.  This is just the
   * name itself in the test policy.
   */
  function tokenUriForName (string memory, string memory name)
      external pure override returns (string memory)
  {
    return name;
  }

  /**
   * @dev Returns a fake contract metadata link.
   */
  function contractUri () external pure override returns (string memory)
  {
    return "contract metadata";
  }

}
