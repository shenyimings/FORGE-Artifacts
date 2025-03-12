pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LAVTStorage.sol";

// Library for adding functionality for handling AVT.
library LAVTManager  {

  // See IAVTManager interface for logs description
  event LogAVTWithdrawn(address indexed sender, uint amount);
  event LogAVTDeposited(address indexed sender, uint amount);

  function withdraw(IAventusStorage _storage, uint _amount)
    external
  {
    decreaseAVT(_storage, msg.sender, _amount);
    _storage.transferAVTTo(msg.sender, _amount);
    emit LogAVTWithdrawn(msg.sender, _amount);
  }

  function deposit(IAventusStorage _storage, uint _amount)
    external
  {
    increaseAVT(_storage, msg.sender, _amount);
    _storage.transferAVTFrom(msg.sender, _amount);
    emit LogAVTDeposited(msg.sender, _amount);
  }

  function transfer(IAventusStorage _storage, uint _amount, address _toAddress)
    external
  {
    require(_amount != 0, "The amount of a transfer must be positive");
    decreaseAVT(_storage, msg.sender, _amount);
    increaseAVT(_storage, _toAddress, _amount);
  }

  function lockDeposit(IAventusStorage _storage, address _account, uint _deposit)
    external
  {
    uint expectedDeposits = LAVTStorage.getExpectedDeposits(_storage, _account) + _deposit;
    uint currentBalance = getBalance(_storage, _account);
    require(currentBalance >= expectedDeposits, "Insufficient balance to cover deposits");
    LAVTStorage.setExpectedDeposits(_storage, _account, expectedDeposits);
  }

  function unlockDeposit(IAventusStorage _storage, address _account, uint _deposit)
    external
  {
    assert(_deposit != 0);
    uint expectedDeposits = LAVTStorage.getExpectedDeposits(_storage, _account);
    assert(expectedDeposits >= _deposit);
    LAVTStorage.setExpectedDeposits(_storage, _account, expectedDeposits - _deposit);
  }

  function getBalance(IAventusStorage _storage, address _account)
    public
    view
    returns (uint balance_)
  {
    balance_ = LAVTStorage.getAVTBalance(_storage, _account);
  }

  function getHistoricBalance(IAventusStorage _storage, address _account, uint _timestamp)
    public
    view
    returns (uint balance_)
  {
    balance_ = LAVTStorage.getHistoricAVTBalance(_storage, _account, _timestamp);
  }

  function decreaseAVT(IAventusStorage _storage, address _account, uint _amount)
    public
  {
    require(!avtIsLockedUpInDeposits(_storage, _amount, _account), "Funds required by a deposit cannot be withdrawn");
    LAVTStorage.decreaseAVT(_storage, _account, _amount);
  }

  function increaseAVT(IAventusStorage _storage,  address _account, uint _amount)
    public
  {
    LAVTStorage.increaseAVT(_storage, _account, _amount);
  }

  function avtIsLockedUpInDeposits(IAventusStorage _storage, uint _amount, address _account)
    private
    view
    returns (bool lockedInDeposits_)
  {
    uint expectedDeposits = LAVTStorage.getExpectedDeposits(_storage, _account);
    uint currentBalance = getBalance(_storage, _account);
    require(_amount <= currentBalance, "Amount taken must be less than current balance");
    // If taking this amount of AVT out will mean we don't have enough deposits then block the withdrawl.
    lockedInDeposits_ = currentBalance - _amount < expectedDeposits;
  }
}