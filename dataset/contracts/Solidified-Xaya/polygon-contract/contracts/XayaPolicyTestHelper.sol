// SPDX-License-Identifier: MIT
// Copyright (C) 2021 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./NftMetadata.sol";
import "./XayaPolicy.sol";

/**
 * @dev Simple wrapper around the XayaPolicy with some methods
 * we need for proper unit testing.
 */
contract XayaPolicyTestHelper is XayaPolicy
{

  constructor (NftMetadata metadata, uint256 initialFee)
    XayaPolicy (metadata, initialFee)
  {}

  /**
   * @dev Calls the policy's checkRegistration function, but accepts bytes
   * instead of string as arguments.  This can be used to pass invalid UTF-8
   * to the contract to check that this is rejected.
   */
  function checkRegistrationWithBytes (bytes memory ns, bytes memory name)
      public view returns (uint256)
  {
    return checkRegistration (string (ns), string (name));
  }

}
