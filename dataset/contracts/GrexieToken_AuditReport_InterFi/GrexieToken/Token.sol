// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import './SafeMath.sol';
import './BasicToken.sol';
import './ERC20.sol';

/**
 * @title Token
 * @dev Token to meet the ERC20 standard
 * @notice https://github.com/ethereum/EIPs/issues/20
 */
contract Token is ERC20, BasicToken {
  mapping(address => mapping(address => uint256)) private allowed;

  /**
   * Token transferFrom function
   * @dev Transfer tokens from one address to another
   * @param _from address to send tokens from
   * @param _to address to transfer to
   * @param _value amout of tokens to be transfered
   */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) public returns (bool) {
    uint256 _allowance = allowed[_from][msg.sender];
    // Safe math functions will throw if value invalid
    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * Token approve function
   * @dev Aprove address to spend amount of tokens
   * @param _spender address to spend the funds.
   * @param _value amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    // To change the approve amount you first have to reduce the addresses`
    // allowance to zero by calling `approve(_spender, 0)` if it is not
    // already 0 to mitigate the race condition described here:
    // @notice https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    assert((_value == 0) || (allowed[msg.sender][_spender] == 0));

    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * Token allowance method
   * @dev Ckeck that owners tokens is allowed to send to spender
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifing the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender)
    public
    view
    returns (uint256 remaining)
  {
    return allowed[_owner][_spender];
  }
}
