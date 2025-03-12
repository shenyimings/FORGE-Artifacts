// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.6.8;


contract NonCompliantToken {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(
    address indexed _owner,
    address indexed _spender,
    uint256 _value
  );

  uint256 public totalSupply;
  uint256 private constant MAX_UINT256 = 2**256 - 1;
  mapping(address => uint256) public balances;
  mapping(address => mapping(address => uint256)) public allowed;
  /*
    NOTE:
    The following variables are OPTIONAL vanities. One does not have to include them.
    They allow one to customise the token contract & in no way influences the core functionality.
    Some wallets/interfaces might not even bother to look at this information.
    */
  string public name; //fancy name: eg Simon Bucks
  uint8 public decimals; //How many decimals to show.
  string public symbol; //An identifier: eg SBX

  constructor() public {
    balances[msg.sender] = 1000000000000000000000; // Give the creator all initial tokens
    totalSupply = 1000000000000000000000; // Update total supply
    name = 'NoncompliantToken'; // Set the name for display purposes
    decimals = 18; // Amount of decimals for display purposes
    symbol = 'NCT'; // Set the symbol for display purposes
  }

  function transfer(address _to, uint256 _value) public {
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    emit Transfer(msg.sender, _to, _value); //solhint-disable-line indent, no-unused-vars
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) public {
    balances[_to] += _value;
    balances[_from] -= _value;
    allowed[_from][msg.sender] -= _value;
    emit Transfer(_from, _to, _value); //solhint-disable-line indent, no-unused-vars
  }

  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

  function approve(address _spender, uint256 _value)
    public
    returns (bool success)
  {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value); //solhint-disable-line indent, no-unused-vars
    return true;
  }
}
