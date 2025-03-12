// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import './SafeMath.sol';
import './ERC20Basic.sol';

/**
 * @title BasicToken
 * @dev Basic version of Token, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;
  mapping(address => uint256) public balances;

  /**
   * BasicToken transfer function
   * @dev transfer token for a specified address
   * @param _to address to transfer to.
   * @param _value amount to be transferred.
   */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(msg.sender != _to, 'cannot send to same account');
    //Safemath fnctions will throw if value is invalid
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
   * BasicToken balanceOf function
   * @dev Gets the balance of the specified address.
   * @param _owner address to get balance of.
   * @return uint256 amount owned by the address.
   */
  function balanceOf(address _owner) public view returns (uint256 bal) {
    return balances[_owner];
  }
}
