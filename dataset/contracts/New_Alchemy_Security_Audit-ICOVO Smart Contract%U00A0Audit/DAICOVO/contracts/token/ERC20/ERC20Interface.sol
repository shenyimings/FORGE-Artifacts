pragma solidity ^0.4.18;

/**
 * Copyright (c) 2016 Smart Contract Solutions, Inc.
 * Released under the MIT license.
 * https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/LICENSE
*/

/**
 * @title 
 * @dev 
 */
contract ERC20Interface {
  string public name;
  string public symbol;
  uint8 public decimals;

  function totalSupply() external view returns (uint256);
  function balanceOf(address who) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

