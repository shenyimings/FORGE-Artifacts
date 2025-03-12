// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "../gauge-pool/interfaces/ILiquidityGaugePool.sol";

contract FakeTokenWithReentrancy {
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
  event Transfer(address indexed from, address indexed to, uint tokens);

  string public constant name = "ERC20Basic";
  string public constant symbol = "BSC";
  uint8 public constant decimals = 18;  

  ILiquidityGaugePool public _pool;
  bytes32 public _target;
  mapping(address => uint256) balances;
  mapping(address => mapping (address => uint256)) allowed;
  uint256 totalSupply_;

  function initialize(ILiquidityGaugePool pool, bytes32 target) public {
    _pool = pool;
    _target = target;
  }

  function totalSupply() public view returns (uint256) {
  	return totalSupply_;
  }
    
  function mint(address tokenOwner, uint256 amount) public {
    balances[tokenOwner] = amount;
  }
    
  function balanceOf(address tokenOwner) public  returns (uint) {
    if (_target == bytes32("setEpoch") && msg.sender == address(_pool)) {
      _pool.setEpoch(2, 1000, 10000);
    }

    return balances[tokenOwner];
  }

  function transfer(address receiver, uint numTokens) public returns (bool) {
    if (_target == bytes32("withdraw") && msg.sender == address(_pool)) {
      _pool.withdraw(1);
    }

    if (_target == bytes32("withdrawRewards") && msg.sender == address(_pool)) {
      _pool.withdrawRewards();
    }

    if (_target == bytes32("exit") && msg.sender == address(_pool)) {
      _pool.exit();
    }

    require(numTokens <= balances[msg.sender]);
    balances[msg.sender] = balances[msg.sender] - numTokens;
    balances[receiver] = balances[receiver] + numTokens;
    emit Transfer(msg.sender, receiver, numTokens);
    return true;
  }

  function approve(address delegate, uint numTokens) public returns (bool) {
    allowed[msg.sender][delegate] = numTokens;
    emit Approval(msg.sender, delegate, numTokens);
    return true;
  }

  function allowance(address owner, address delegate) public view returns (uint) {
    return allowed[owner][delegate];
  }

  function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
    if (_target == bytes32("deposit") && msg.sender == address(_pool)) {
      _pool.deposit(1);
    }
    
    require(numTokens <= balances[owner]);    
    require(numTokens <= allowed[owner][msg.sender]);

    balances[owner] = balances[owner] - numTokens;
    allowed[owner][msg.sender] = allowed[owner][msg.sender] - numTokens;
    balances[buyer] = balances[buyer] + numTokens;
    emit Transfer(owner, buyer, numTokens);
    return true;
  }
}



