pragma solidity 0.5.12;

interface IEventsManager {

  /**
   * @notice Event emitted for a createEvent transaction.
   */
  event LogEventCreated(uint indexed eventId, address indexed eventOwner, string eventDesc, bytes rules);

  /**
   * @notice Event emitted for a registerRoleOnEvent transaction.
   */
  event LogEventRoleRegistered(uint indexed eventId, address indexed roleAddress, string role);

  /**
   * @notice Create an event
   * @param _eventDesc Description of the event
   * @param _eventRef unique identifier for the event - no two events for this eventOwner can have the same eventRef
   * @param _ownerProof The event details signed by the owner
   * @param _eventOwner The event owner
   * @param _rules encoded ticket rules for this event
   */
  function createEvent(string calldata _eventDesc, bytes32 _eventRef, bytes calldata _ownerProof, address _eventOwner,
      bytes calldata _rules) external;

  /**
   * @notice Register a validator for an event
   * @param _eventId ID of the event
   * @param _roleAddress address associated with the role
   * @param _role must be either "Primary" or "Secondary"
   * @param _registerRoleEventOwnerProof signed proof from the event owner for registering a role
   */
  function registerRoleOnEvent(uint _eventId, address _roleAddress, string calldata _role,
      bytes calldata _registerRoleEventOwnerProof) external;

  /**
   * @notice Check the validity of a single condition for a rule
   * @notice Reverts if conditionData is encoded incorrectly
   * @param _conditionData encoded condition
   */
  function checkRuleCondition(bytes calldata _conditionData) external;

  /**
   * @notice Check the validity of a single rule (set of conditions)
   * @notice Reverts if ruleData is encoded incorrectly
   * @param _ruleData encoded rule
   */
  function checkRule(bytes calldata _ruleData) external;

  /**
   * @notice Check the validity of the set of rules which apply to a single transaction type
   * @notice Reverts if transactionRulesData is encoded incorrectly
   * @param _transactionRulesData encoded rules for transaction type
   */
  function checkTransactionRules(bytes calldata _transactionRulesData) external;

  /**
   * @notice Check the validity of the set of transaction rules (all the rules applied at event level across transaction types)
   * @notice Reverts if eventRulesData is encoded incorrectly
   * @param _eventRulesData encoded sets of transaction rules
   */
  function checkEventRules(bytes calldata _eventRulesData) external;
}