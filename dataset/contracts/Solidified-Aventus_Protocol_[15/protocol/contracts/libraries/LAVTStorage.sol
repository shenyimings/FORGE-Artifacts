pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LAventusTime.sol";

library LAVTStorage {

  string constant avtAccountTable = "AVTAccount";

  function getAVTBalance(IAventusStorage _storage, address _account)
    external
    view
    returns (uint balance_)
  {
    balance_ = _storage.getUInt(keccak256(abi.encodePacked(avtAccountTable, _account, "Balance")));
  }

  // Binary search of an account's AVT balance history returns balance on or directly preceding specified timestamp.
  // Search will fail if the number of AVT transactions submitted for an account has exceeded 10^781 * age_of_the_universe.
  function getHistoricAVTBalance(IAventusStorage _storage, address _account, uint _targetTimestamp)
    external
    view
    returns (uint)
  {
    uint length = _storage.getUInt(keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryLength")));

    if (length == 0)
      return 0;

    bytes32 timeKey = keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryTimestamp", length));
    bytes32 balanceKey = keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryBalance", length));

    if (_targetTimestamp >= _storage.getUInt(timeKey))
      return _storage.getUInt(balanceKey);

    uint lo = 1;
    uint hi = length;

    while (lo <= hi) {
      uint mid = (lo + hi) / uint(2);
      uint midTimestamp = _storage.getUInt(keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryTimestamp", mid)));
      if (_targetTimestamp < midTimestamp)
        hi = mid - 1;
      else if (_targetTimestamp > midTimestamp)
        lo = mid + 1;
      else {
        hi = mid;
        break;
      }
    }

    balanceKey = keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryBalance", hi));
    return _storage.getUInt(balanceKey);
  }

  function decreaseAVT(IAventusStorage _storage, address _account, uint _amount)
    external
  {
    bytes32 key = keccak256(abi.encodePacked(avtAccountTable, _account, "Balance"));
    uint currentBalance = _storage.getUInt(key);
    assert(_amount <= currentBalance);
    uint newBalance = currentBalance - _amount;
    _storage.setUInt(key, newBalance);
    updateAVTHistory(_storage, _account, newBalance);
  }

  function increaseAVT(IAventusStorage _storage, address _account, uint _amount)
    external
  {
    bytes32 key = keccak256(abi.encodePacked(avtAccountTable, _account, "Balance"));
    require(_amount != 0, "Added amount must be greater than zero");
    uint newBalance = _storage.getUInt(key) + _amount;
    _storage.setUInt(key, newBalance);
    updateAVTHistory(_storage, _account, newBalance);
  }

  function getExpectedDeposits(IAventusStorage _storage, address _account)
    external
    view
    returns (uint expectedDeposits_)
  {
    expectedDeposits_ = _storage.getUInt(keccak256(abi.encodePacked(avtAccountTable, _account, "ExpectedDeposits")));
  }

  function setExpectedDeposits(IAventusStorage _storage, address _account, uint _expectedDeposits)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(avtAccountTable, _account, "ExpectedDeposits")), _expectedDeposits);
  }

  // updates the virtual array structure of an AVT account's balance history
  function updateAVTHistory(IAventusStorage _storage, address _account, uint _balance)
    private
  {
    bytes32 lengthKey = keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryLength"));
    uint length = _storage.getUInt(lengthKey);
    bytes32 timeKey = keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryTimestamp", length));
    uint timestamp = LAventusTime.getCurrentTime(_storage);

    if (timestamp != _storage.getUInt(timeKey))
      timeKey = keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryTimestamp", ++length));

    bytes32 balanceKey = keccak256(abi.encodePacked(avtAccountTable, _account, "HistoryBalance", length));
    _storage.setUInt(timeKey, timestamp);
    _storage.setUInt(balanceKey, _balance);
    _storage.setUInt(lengthKey, length);
  }
}