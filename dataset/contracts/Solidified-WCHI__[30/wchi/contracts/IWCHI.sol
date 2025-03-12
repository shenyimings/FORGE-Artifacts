// SPDX-License-Identifier: MIT
// Copyright (C) 2021 Autonomous Worlds Ltd

pragma solidity ^0.7.6;

import "./IERC20.sol";

/**
 * @dev Interface for the wrapped CHI (WCHI) token.
 */
interface IWCHI is IERC20
{

  /**
   * @dev Burns the given number of tokens, reducing total supply.
   */
  function burn (uint256 value) external;

}
