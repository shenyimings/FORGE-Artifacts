pragma solidity 0.5.12;

import "./LEventsStorage.sol";
import "./LValidators.sol";
import "./zeppelin/LECRecovery.sol";

library LEventsEvents {

  modifier onlyWithEventDescription(IAventusStorage _storage, string memory _eventDesc) {
    require(bytes(_eventDesc).length != 0, "Event requires a non-empty description");
    _;
  }

  struct RuleSet {
    uint transactionType;
    bytes rules;
  }

  function createEvent(IAventusStorage _storage, string calldata _eventDesc, bytes32 _eventRef,
      bytes calldata _createEventEventOwnerProof, address _eventOwner, bytes calldata _rules)
    external
    onlyWithEventDescription(_storage, _eventDesc)
    returns (uint eventId_)
  {
    address signer = LECRecovery.recover(keccak256(abi.encodePacked(keccak256(abi.encodePacked(_eventDesc)), _rules)),
      _createEventEventOwnerProof);
    require(signer == _eventOwner, "Creation proof must be valid and signed by event owner");

    if (msg.sender != _eventOwner)
      LValidators.ensureValidatorIsRegistered(_storage);

    eventId_ = uint(keccak256(abi.encodePacked(_eventRef, _eventOwner)));
    LEventsStorage.setEventOwner(_storage, eventId_, _eventOwner);
    checkAndSetEventRules(_storage, eventId_, _rules);
  }

  function getTransactionRules(IAventusStorage _storage, uint _eventId, uint _transactionType)
    external
    view
    returns (bytes memory rules_)
  {
    rules_ = LEventsStorage.getTransactionRules(_storage, _eventId, _transactionType);
  }

  function getEventOwner(IAventusStorage _storage, uint _eventId)
    public
    view
    returns (address eventOwner_)
  {
    eventOwner_ = LEventsStorage.getEventOwner(_storage, _eventId);
  }

  function isEventOwner(IAventusStorage _storage, uint _eventId, address _owner)
    public
    view
    returns (bool valid_)
  {
    valid_ = _owner == getEventOwner(_storage, _eventId);
  }

  function checkAndSetEventRules(IAventusStorage _storage, uint _eventId, bytes memory _ruleSets)
    private
  {
    if (_ruleSets.length == 0) {
      return;
    }

    (bytes memory firstRuleSet, bytes memory otherRuleSets) = abi.decode(_ruleSets, (bytes, bytes));
    RuleSet memory ruleSet;
    (ruleSet.transactionType, ruleSet.rules) = abi.decode(firstRuleSet, (uint, bytes));

    LEventsStorage.setTransactionRules(_storage, _eventId, ruleSet.transactionType, ruleSet.rules);

    checkAndSetEventRules(_storage, _eventId, otherRuleSets);
  }
}