// SPDX-License-Identifier: MIT
// Copyright (C) 2021 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

/**
 * @dev Utility library for building up strings in Solidity bit-by-bit,
 * without the need to re-allocate the string for each bit.
 */
library StringBuilder
{

  /**
   * @dev A string being built.  This is just a bytes array of a given
   * allocated size, and the current length (which might be smaller than
   * the allocated size).
   */
  struct Type
  {

    /**
     * @dev The allocated data array.  The size (stored in the first slot)
     * is set to the actual (current) length, rather than the allocated one.
     */
    bytes data;

    /** @dev The maximum / allocated size of the data array.  */
    uint maxLen;

  }

  /**
   * @dev Constructs a new builder that is empty initially but has space
   * for the given number of bytes.
   */
  function create (uint maxLen) internal pure returns (Type memory res)
  {
    bytes memory data = new bytes (maxLen);

    assembly {
      mstore (data, 0)
    }

    res.data = data;
    res.maxLen = maxLen;
  }

  /**
   * @dev Extracts the current data from a builder instance as string.
   */
  function extract (Type memory b) internal pure returns (string memory)
  {
    return string (b.data);
  }

  /**
   * @dev Adds the given string to the content of the builder.  This must
   * not exceed the allocated maximum size.
   */
  function append (Type memory b, string memory str) internal pure
  {
    bytes memory buf = b.data;
    bytes memory added = bytes (str);

    uint256 oldLen = buf.length;
    uint256 newLen = oldLen + added.length;
    require (newLen <= b.maxLen, "StringBuilder maxLen exceeded");
    assembly {
      mstore (buf, newLen)
    }

    for (uint i = 0; i < added.length; ++i)
      buf[i + oldLen] = added[i];
  }

}
