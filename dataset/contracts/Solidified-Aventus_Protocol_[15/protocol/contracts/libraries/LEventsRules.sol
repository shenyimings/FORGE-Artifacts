pragma solidity 0.5.12;

import "./LEnums.sol";

library LEventsRules {

  function checkRuleCondition(bytes memory _condition)
    public
    pure
  {
    (, uint conditionTypeAsUint, bytes memory constraints) = abi.decode(_condition, (string, uint, bytes));

    LEnums.ConditionType conditionType = LEnums.validateConditionType(conditionTypeAsUint);

    if (conditionType == LEnums.ConditionType.TicketGroupMatches)
      abi.decode(constraints, (string, bool));
    else if (conditionType == LEnums.ConditionType.TicketOwnerIsInWhitelist)
      abi.decode(constraints, (bool));
    else if (conditionType == LEnums.ConditionType.TransactionTimeIsBetween)
      abi.decode(constraints, (uint, uint));
    else
      abi.decode(constraints, (uint));
  }

  function checkRule(bytes memory _rule)
    public
    pure
  {
    (, bytes memory conditions) = abi.decode(_rule, (string, bytes));

    doCheckConditions(conditions);
  }

  function checkTransactionRules(bytes memory _transactionRules)
    public
    pure
  {
    (uint transactionTypeAsUint, bytes memory rules) = abi.decode(_transactionRules, (uint, bytes));
    LEnums.validateTransactionType(transactionTypeAsUint);

    doCheckRules(rules);
  }

  function checkEventRules(bytes memory _eventRules)
    public
    pure
  {
    (bytes memory transactionRules, bytes memory otherTransactionRules) = abi.decode(_eventRules, (bytes, bytes));

    checkTransactionRules(transactionRules);

    if (otherTransactionRules.length != 0)
      checkEventRules(otherTransactionRules);
  }

  function doCheckConditions(bytes memory _conditions)
    private
    pure
  {
    (bytes memory condition, bytes memory otherConditions) = abi.decode(_conditions, (bytes, bytes));

    checkRuleCondition(condition);

    if (otherConditions.length != 0)
      doCheckConditions(otherConditions);
  }

  function doCheckRules(bytes memory _rules)
    private
    pure
  {
    (bytes memory rule, bytes memory otherRules) = abi.decode(_rules, (bytes, bytes));

    checkRule(rule);

    if (otherRules.length != 0)
      doCheckRules(otherRules);
  }
}