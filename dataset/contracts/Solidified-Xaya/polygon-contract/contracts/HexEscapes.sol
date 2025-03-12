// SPDX-License-Identifier: MIT
// Copyright (C) 2021 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./StringBuilder.sol";

/**
 * @dev A Solidity library for escaping UTF-8 characters into
 * hex sequences, e.g. for JSON string literals.
 */
library HexEscapes
{

  /** @dev Hex characters used.  */
  bytes internal constant HEX = bytes ("0123456789ABCDEF");

  /**
   * @dev Converts a single uint16 number into a \uXXXX JSON escape
   * string.  This does not do any UTF-16 surrogate pair conversion.
   */
  function jsonUint16 (uint16 val) private pure returns (string memory)
  {
    bytes memory res = bytes ("\\uXXXX");

    for (uint i = 0; i < 4; ++i)
      {
        res[5 - i] = HEX[val & 0xF];
        val >>= 4;
      }

    return string (res);
  }

  /**
   * @dev Converts a given Unicode codepoint into a corresponding
   * escape sequence inside a JSON literal.  This takes care of encoding
   * it into either one or two \uXXXX sequences based on UTF-16.
   */
  function jsonCodepoint (uint32 val) internal pure returns (string memory)
  {
    if (val < 0xD800 || (val >= 0xE000 && val < 0x10000))
      return jsonUint16 (uint16 (val));

    require (val >= 0x10000 && val < 0x110000, "invalid codepoint");

    val -= 0x10000;
    return string (abi.encodePacked (
      jsonUint16 (0xD800 | uint16 (val >> 10)),
      jsonUint16 (0xDC00 | uint16 (val & 0x3FF))
    ));
  }

  /**
   * @dev Converts a given Unicode codepoint into an XML escape sequence.
   */
  function xmlCodepoint (uint32 val) internal pure returns (string memory)
  {
    bytes memory res = bytes ("&#x000000;");

    for (uint i = 0; val > 0; ++i)
      {
        require (i < 6, "codepoint does not fit into 24 bits");

        res[8 - i] = HEX[val & 0xF];
        val >>= 4;
      }

    return string (res);
  }

  /**
   * @dev Converts a binary string into all-hex characters.
   */
  function hexlify (string memory str) internal pure returns (string memory)
  {
    bytes memory data = bytes (str);
    StringBuilder.Type memory builder = StringBuilder.create (2 * data.length);

    for (uint i = 0; i < data.length; ++i)
      {
        bytes memory cur = bytes ("xx");

        uint8 val = uint8 (data[i]);
        cur[1] = HEX[val & 0xF];
        val >>= 4;
        cur[0] = HEX[val & 0xF];

        StringBuilder.append (builder, string (cur));
      }

    return StringBuilder.extract (builder);
  }

}
