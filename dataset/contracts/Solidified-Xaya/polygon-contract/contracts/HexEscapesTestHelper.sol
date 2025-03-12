// SPDX-License-Identifier: MIT
// Copyright (C) 2022 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./HexEscapes.sol";

/**
 * @dev Wrapper contract around the HexEscapes library so we can
 * easily call its functions for unit testing.
 */
contract HexEscapesTestHelper
{

  function jsonCodepoint (uint32 val) public pure returns (string memory)
  {
    return HexEscapes.jsonCodepoint (val);
  }

  function xmlCodepoint (uint32 val) public pure returns (string memory)
  {
    return HexEscapes.xmlCodepoint (val);
  }

  function hexlify (string memory str) public pure returns (string memory)
  {
    return HexEscapes.hexlify (str);
  }

}
