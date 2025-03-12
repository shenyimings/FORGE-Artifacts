// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import './ERC20Basic.sol';

/**
 * ERC20 interface
 * @title ERC20 interface
 * @notice https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  /**
   * allowance
   */
  function allowance(address owner, address spender)
    public
    view
    returns (uint256);

  /**
   * transferFrom
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public returns (bool);

  /**
   * approve
   */
  function approve(address spender, uint256 value) public returns (bool);

  /**
   * Approval event
   */
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
