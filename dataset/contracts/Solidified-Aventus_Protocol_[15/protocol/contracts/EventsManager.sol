pragma solidity 0.5.12;

import "./interfaces/IAventusStorage.sol";
import "./interfaces/IEventsManager.sol";
import "./libraries/LEvents.sol";
import "./Owned.sol";
import "./Versioned.sol";

contract EventsManager is IEventsManager, Owned, Versioned {

  IAventusStorage public s;

  constructor(IAventusStorage _s)
    public
  {
    s = _s;
  }

  function createEvent(string calldata _eventDesc, bytes32 _eventRef, bytes calldata _ownerProof, address _eventOwner,
      bytes calldata _rules)
    external
  {
    LEvents.createEvent(s, _eventDesc, _eventRef, _ownerProof, _eventOwner, _rules);
  }

  function registerRoleOnEvent(uint _eventId, address _roleAddress, string calldata _role,
      bytes calldata _registerRoleEventOwnerProof)
    external
  {
    LEvents.registerRoleOnEvent(s, _eventId, _roleAddress, _role, _registerRoleEventOwnerProof);
  }

  function checkRuleCondition(bytes calldata _conditionData)
    external
  {
    LEvents.checkRuleCondition(s, _conditionData);
  }

  function checkRule(bytes calldata _ruleData)
    external
  {
    LEvents.checkRule(s, _ruleData);
  }

  function checkTransactionRules(bytes calldata _transactionRulesData)
    external
  {
    LEvents.checkTransactionRules(s, _transactionRulesData);
  }

  function checkEventRules(bytes calldata _eventRulesData)
    external
  {
    LEvents.checkEventRules(s, _eventRulesData);
  }
}