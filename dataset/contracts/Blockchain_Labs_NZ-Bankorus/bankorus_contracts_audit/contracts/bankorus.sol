pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract Bankorus is StandardToken, Ownable {

  using SafeMath for uint256;

  string public name = "Bankorus";
  string public symbol = "BKT";
  uint8 public decimals = 18;
  uint256 public arrayLimit = 20;

  function Bankorus(uint256 _totalSupply) public {
    totalSupply_ = _totalSupply * 10 ** uint256(decimals);
    balances[owner] = totalSupply_;
    Transfer(address(0), owner, totalSupply_);
  }

  function setArrayLimit(uint256 _newLimit) onlyOwner public {
    require(_newLimit > 0);
    arrayLimit = _newLimit;
  }

  function transferToAddresses(address[] _addresses, uint256[] _values) onlyOwner public returns (bool success) {
    require(_addresses.length == _values.length);
    require(_addresses.length <= arrayLimit);

    uint256 i = 0;
    for (i; i < _addresses.length; i++) {
      require(super.transfer(_addresses[i], _values[i]));
    }
    return true;
  }

}
