pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LAventusTime.sol";

library LEventsStorage {

  string constant eventTable = "Event";

  function isRoleOnEvent(IAventusStorage _storage, uint _eventId, address _roleAddress, string calldata _role)
    external
    view
    returns (bool isRegistered_)
  {
    bytes32 roleAddressKey = keccak256(abi.encodePacked(eventTable, _eventId, "Role", _role, "Address", _roleAddress));
    isRegistered_ = _storage.getBoolean(roleAddressKey);
  }

  function setRoleOnEvent(IAventusStorage _storage, uint _eventId, address _roleAddress, string calldata _role)
    external
  {
    _storage.setBoolean(keccak256(abi.encodePacked(eventTable, _eventId, "Role", _role, "Address", _roleAddress)), true);
  }

  function setEventOwner(IAventusStorage _storage, uint _eventId, address _eventOwner)
    external
  {
    require(getEventOwner(_storage, _eventId) == address(0), "Event already exists");
    _storage.setAddress(keccak256(abi.encodePacked(eventTable, _eventId, "Owner")), _eventOwner);
  }

  function setTransactionRules(IAventusStorage _storage, uint _eventId, uint _transactionType, bytes calldata _rules)
    external
  {
    require(getTransactionRules(_storage, _eventId, _transactionType).length == 0, "Rule duplicates for transaction type");
    _storage.setBytes(keccak256(abi.encodePacked(eventTable, _eventId, _transactionType, "Rules")), _rules);
  }

  function getTransactionRules(IAventusStorage _storage, uint _eventId, uint _transactionType)
    public
    view
    returns (bytes memory rules_)
  {
    rules_ = _storage.getBytes(keccak256(abi.encodePacked(eventTable, _eventId, _transactionType, "Rules")));
  }

  function getEventOwner(IAventusStorage _storage, uint _eventId)
    public
    view
    returns (address eventOwner_)
  {
    eventOwner_ = _storage.getAddress(keccak256(abi.encodePacked(eventTable, _eventId, "Owner")));
  }
}
