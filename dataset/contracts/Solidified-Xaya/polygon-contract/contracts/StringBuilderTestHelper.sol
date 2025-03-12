// SPDX-License-Identifier: MIT
// Copyright (C) 2022 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./StringBuilder.sol";

/**
 * @dev Simple wrapper contract around the library StringBuilder,
 * which allows us to exercise the library functions for unit tests.
 *
 * The contract holds an instance of the StringBuilder state, and tests
 * deploy instances of the contract as needed.
 */
contract StringBuilderTestHelper
{

  /** @dev The StringBuilder state under test.  */
  StringBuilder.Type internal state;

  constructor (uint maxLen)
  {
    state = StringBuilder.create (maxLen);
  }

  /**
   * @dev Extracts the current string from the internal builder.
   */
  function extract () public view returns (string memory)
  {
    return StringBuilder.extract (state);
  }

  /**
   * @dev Appends the given string to the internal state.
   */
  function append (string memory str) public
  {
    StringBuilder.Type memory temp = state;
    StringBuilder.append (temp, str);
    state = temp;
  }

}
