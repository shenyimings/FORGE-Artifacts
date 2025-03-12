pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LAventusTime.sol";
import "./LEventsEvents.sol";
import "./LEventsRoles.sol";
import "./LEventsRules.sol";

/* @dev All external methods which are only called from EventsManager have the same function signature (and interface
 * documentation) as their namesakes in EventsManager.
 *
 * All external methods here should do the following and ONLY the following:
 *   - check that the event is in the correct state
 *   - call the method of the same name in a sublibrary to actually make the required change
 *   - emit the correct log if necessary
 * In particular, the methods SHOULD NOT check proofs or msg.sender validity - these checks should be done in the sublibrary.
 */

library LEvents {

  // See IEventsManager interface for logs description
  event LogEventCreated(uint indexed eventId, address indexed eventOwner, string eventDesc, bytes rules);
  event LogEventRoleRegistered(uint indexed eventId, address indexed roleAddress, string role);

  modifier onlyWhenExistent(IAventusStorage _storage, uint _eventId) {
    require(address(0) != getEventOwner(_storage, _eventId), "Event must exist");
    _;
  }

  function createEvent(IAventusStorage _storage, string calldata _eventDesc, bytes32 _eventRef,
      bytes calldata _createEventOwnerProof, address _eventOwner, bytes calldata _rules)
    external
  {
    uint eventId = LEventsEvents.createEvent(_storage, _eventDesc, _eventRef, _createEventOwnerProof, _eventOwner, _rules);

    emit LogEventCreated(eventId, _eventOwner, _eventDesc, _rules);
  }

  function registerRoleOnEvent(IAventusStorage _storage, uint _eventId, address _roleAddress, string calldata _role,
      bytes calldata _registerRoleEventOwnerProof)
    external
    onlyWhenExistent(_storage, _eventId)
  {
    LEventsRoles.registerRoleOnEvent(_storage, _eventId, _roleAddress, _role, _registerRoleEventOwnerProof);
    emit LogEventRoleRegistered(_eventId, _roleAddress, _role);
  }

  function isEventOwnerOrRole(IAventusStorage _storage, uint _eventId, address _address, string calldata _role)
    external
    view
    returns (bool isOwnerOrRole_)
  {
    isOwnerOrRole_ = LEventsRoles.isEventOwnerOrRole(_storage, _eventId, _address, _role);
  }

  function getTransactionRules(IAventusStorage _storage, uint _eventId, uint _transactionType)
    external
    view
    returns (bytes memory rules_)
  {
    rules_ = LEventsEvents.getTransactionRules(_storage, _eventId, _transactionType);
  }

  function checkRuleCondition(IAventusStorage /*_storage*/, bytes calldata _conditionData)
    external
    pure
  {
    LEventsRules.checkRuleCondition(_conditionData);
  }

  function checkRule(IAventusStorage /*_storage*/, bytes calldata _ruleData)
    external
    pure
  {
    LEventsRules.checkRule(_ruleData);
  }

  function checkTransactionRules(IAventusStorage /*_storage*/, bytes calldata _transactionRulesData)
    external
    pure
  {
    LEventsRules.checkTransactionRules(_transactionRulesData);
  }

  function checkEventRules(IAventusStorage /*_storage*/, bytes calldata _eventRulesData)
    external
    pure
  {
    LEventsRules.checkEventRules(_eventRulesData);
  }

  function getEventOwner(IAventusStorage _storage, uint _eventId)
    public
    view
    returns (address eventOwner_)
  {
    eventOwner_ = LEventsEvents.getEventOwner(_storage, _eventId);
  }
}