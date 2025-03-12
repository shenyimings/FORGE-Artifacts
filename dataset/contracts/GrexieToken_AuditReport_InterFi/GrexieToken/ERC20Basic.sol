// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

/**
 * @title ERC20Basic
 * @dev Simple version of ERC20 interface
 * @notice https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  /**
   * @dev Returns the name of the token.
   * @return _name Token name.
   */
  function name() external view returns (string memory _name);

  /**
   * @dev Returns the symbol of the token.
   * @return _symbol Token symbol.
   */
  function symbol() external view returns (string memory _symbol);

  /**
   * @dev Returns the number of decimals the token uses.
   * @return _decimals Number of decimals.
   */
  function decimals() external view returns (uint8 _decimals);

  /**
   * @dev Returns the total token supply.
   * @return _totalSupply Total supply.
   */
  function totalSupply() external view returns (uint256 _totalSupply);

  /**
   * Balance of address
   */
  function balanceOf(address who) public view returns (uint256);

  /**
   * Transfer value to address
   */
  function transfer(address to, uint256 value) public returns (bool);

  /**
   * Transfer event
   */
  event Transfer(address indexed from, address indexed to, uint256 value);
}
