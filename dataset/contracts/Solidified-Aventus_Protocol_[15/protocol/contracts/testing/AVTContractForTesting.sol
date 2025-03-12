pragma solidity 0.5.12;

import "../interfaces/IERC20.sol";

// NOTE: Includes optional fields.
// See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md for details.
contract AVTContractForTesting is IERC20 {
  string public constant name = "Aventus";
  string public constant symbol = "AVT";
  uint8 public constant decimals = 18;

  uint private constant oneAVTInAttoAVT = 10**uint(decimals);
  uint private constant totalSupplyInAVT = 10000000; // 10,000,000 - same as the one on mainnet so we don't go over this.
  uint private constant totalSupplyInAttoAVT = totalSupplyInAVT * oneAVTInAttoAVT;
  mapping (address => uint) balances;
  mapping (address => mapping (address => uint)) approvals;

  constructor ()
    public
  {
    balances[msg.sender] = totalSupplyInAttoAVT;
  }

  function totalSupply()
    external
    view
    returns (uint totalSupply_)
  {
    totalSupply_ = totalSupplyInAttoAVT;
  }

  function balanceOf(address _owner)
    external
    view
    returns (uint balance_)
  {
    balance_ = balances[_owner];
  }

  function transfer(address _to, uint _value)
    external
    returns (bool success_)
  {
    success_ = balances[msg.sender] >= _value;
    require(success_, '');
    balances[msg.sender] -= _value;
    balances[_to] += _value;
  }

  function transferFrom(address _from, address _to, uint _value)
    external
    returns (bool success_)
  {
    success_ = balances[_from] >= _value && approvals[_from][_to] >= _value;
    require(success_, '');
    approvals[_from][_to] -= _value;
    balances[_from] -= _value;
    balances[_to] += _value;
  }

  function approve(address _spender, uint _value)
    external
    returns (bool success_)
  {
    approvals[msg.sender][_spender] = _value;
    success_ = true;
  }

  function allowance(address _owner, address _spender)
    external
    view
    returns (uint remaining_)
  {
    remaining_ = approvals[_owner][_spender];
  }
}