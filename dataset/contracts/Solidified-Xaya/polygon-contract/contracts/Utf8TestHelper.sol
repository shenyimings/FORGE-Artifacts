// SPDX-License-Identifier: MIT
// Copyright (C) 2021 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./Utf8.sol";

/**
 * @dev Simple wrapper contract around the Utf8 library so we can call
 * its internal functions from unit tests.
 */
contract Utf8TestHelper
{

  function decodeCodepoint (bytes memory data, uint offset)
      public pure returns (uint32 cp, uint newOffset)
  {
    return Utf8.decodeCodepoint (data, offset);
  }

  function validate (bytes memory data) public pure
  {
    Utf8.validate (data);
  }

}
