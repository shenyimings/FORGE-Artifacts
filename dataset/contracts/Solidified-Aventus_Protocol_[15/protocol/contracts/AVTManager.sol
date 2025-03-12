pragma solidity 0.5.12;

import "./interfaces/IAventusStorage.sol";
import "./interfaces/IAVTManager.sol";
import "./libraries/LAVTManager.sol";
import "./Owned.sol";
import "./Versioned.sol";

contract AVTManager is IAVTManager, Owned, Versioned {

  IAventusStorage public s;

  constructor(IAventusStorage _s)
    public
  {
    s = _s;
  }

  function withdraw(uint _amount)
    external
  {
    LAVTManager.withdraw(s, _amount);
  }

  function deposit(uint _amount)
    external
  {
    LAVTManager.deposit(s, _amount);
  }

  function transfer(uint _amount, address _toAddress)
    external
  {
    LAVTManager.transfer(s, _amount, _toAddress);
  }

  function getBalance(address _account)
    external
    view
    returns (uint balance_)
  {
    balance_ = LAVTManager.getBalance(s, _account);
  }

  function getHistoricBalance(address _account, uint _timestamp)
    external
    view
    returns (uint balance_)
  {
    balance_ = LAVTManager.getHistoricBalance(s, _account, _timestamp);
  }
}