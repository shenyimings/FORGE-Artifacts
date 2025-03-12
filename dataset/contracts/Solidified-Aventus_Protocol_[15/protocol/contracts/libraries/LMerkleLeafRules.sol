pragma solidity 0.5.12;

import "./LEnums.sol";

library LMerkleLeafRules {

  struct ImmutableRulesData {
    string ticketGroup;
    address[] whitelist;
  }

  struct MutableRulesData {
    uint numResells;
    uint numTransfers;
  }

  struct Condition {
    string name;
    LEnums.ConditionType conditionType;
    bytes constraints;
  }

  // iff ALL conditions pass, leaf passes that rule.
  struct Rule {
    string name;
    bytes conditions;  // abi encoded array of Conditions: all conditions must be met.
  }

  // NOTE: This MUST NOT assert. Reverts are fine. See LMerkleLeafChecks.checkLeafFormat.
  function checkRulesDataFormat(bytes calldata _immutableRulesData, bytes calldata _mutableRulesData)
    external
    pure
  {
    decodeImmutableRulesData(_immutableRulesData);
    decodeMutableRulesData(_mutableRulesData);
  }

  function checkLeafLifecycle(LEnums.TransactionType _transactionType, bytes calldata _mutableRulesData,
      bytes calldata _prevMutableRulesData)
    external
    pure
    returns (string memory checkFailedReason_)
  {
    MutableRulesData memory mutableRulesData = decodeMutableRulesData(_mutableRulesData);
    MutableRulesData memory prevMutableRulesData = decodeMutableRulesData(_prevMutableRulesData);

    if (_transactionType == LEnums.TransactionType.Resell) {
      if (mutableRulesData.numResells != prevMutableRulesData.numResells + 1) {
        return "Resell must increment num resells in rules data";
      }
      if (mutableRulesData.numTransfers != prevMutableRulesData.numTransfers) {
        return "Resell must not modify num transfers in rules data";
      }
    } else if (_transactionType == LEnums.TransactionType.Transfer) {
      if (mutableRulesData.numResells != prevMutableRulesData.numResells) {
        return "Transfer must not modify num resells in rules data";
      }
      if (mutableRulesData.numTransfers != prevMutableRulesData.numTransfers + 1) {
        return "Transfer must increment num transfers in rules data";
      }
    } else {
      if (keccak256(_mutableRulesData) != keccak256(_prevMutableRulesData)) {
        return "Transaction must not modify rules data";
      }
    }
  }

  function checkRulesConsistencySell(bytes calldata _mutableRulesData)
    external
    pure
    returns (string memory checkFailedReason_)
  {
    MutableRulesData memory mutableRulesData = decodeMutableRulesData(_mutableRulesData);
    if (mutableRulesData.numResells != 0)
      checkFailedReason_ = "Sell must have zero value for num resells in rules data";
    else if (mutableRulesData.numTransfers != 0)
      checkFailedReason_ = "Sell must have zero value for num transfers in rules data";
  }

  function runRules(bytes calldata _rules, uint _rootRegistrationTime, bytes calldata _immutableRulesData,
      bytes calldata _mutableRulesData, address _ticketOwner)
    external
    pure
    returns (string memory ruleFailedReason_)
  {
    ImmutableRulesData memory immutableRulesData = decodeImmutableRulesData(_immutableRulesData);
    MutableRulesData memory mutableRulesData = decodeMutableRulesData(_mutableRulesData);

    return doRunRules(_rules, _rootRegistrationTime, immutableRulesData, mutableRulesData, _ticketOwner);
  }

  function doRunRules(bytes memory _rules, uint _rootRegistrationTime, ImmutableRulesData memory _immutableRulesData,
      MutableRulesData memory _mutableRulesData, address _ticketOwner)
    private
    pure
    returns (string memory ruleFailedReason_)
  {
    (bytes memory firstRule, bytes memory otherRules) = abi.decode(_rules, (bytes, bytes));
    Rule memory rule;
    (rule.name, rule.conditions) = abi.decode(firstRule, (string, bytes));

    ruleFailedReason_ = runConditions(rule.conditions, _rootRegistrationTime, _immutableRulesData, _mutableRulesData,
        _ticketOwner);
    if (bytes(ruleFailedReason_).length == 0) {
      // Rules are OR'd together, so if a single rule passes for a leaf, that is sufficient to pass the leaf.
      return "";
    }
    ruleFailedReason_ = string(abi.encodePacked(rule.name, " - ", ruleFailedReason_));

    if (otherRules.length == 0) {
      return ruleFailedReason_;
    }

    string memory otherRulesFailedReasons = doRunRules(otherRules, _rootRegistrationTime, _immutableRulesData,
        _mutableRulesData, _ticketOwner);
    if (bytes(otherRulesFailedReasons).length == 0) {
      return "";
    }

    return string(abi.encodePacked(ruleFailedReason_, "; ", otherRulesFailedReasons));
  }

  // NOTE: This MUST NOT assert. Reverts are fine. See checkRulesDataFormat.
  function decodeImmutableRulesData(bytes memory _immutableRulesData)
    private
    pure
    returns (ImmutableRulesData memory immutableRulesData_)
  {
    (immutableRulesData_.ticketGroup, immutableRulesData_.whitelist) = abi.decode(_immutableRulesData, (string, address[]));
  }

  // NOTE: This MUST NOT assert. Reverts are fine. See checkRulesDataFormat.
  function decodeMutableRulesData(bytes memory _mutableRulesData)
    private
    pure
    returns (MutableRulesData memory mutableRulesData_)
  {
    (mutableRulesData_.numResells, mutableRulesData_.numTransfers) = abi.decode(_mutableRulesData, (uint, uint));
  }

  function runConditions(bytes memory _conditions, uint _rootRegistrationTime, ImmutableRulesData memory _immutableRulesData,
      MutableRulesData memory _mutableRulesData, address _ticketOwner)
    private
    pure
    returns (string memory conditionFailedReason_)
  {
    (bytes memory firstCondition, bytes memory otherConditions) = abi.decode(_conditions, (bytes, bytes));
    Condition memory condition;
    // NOTE: Invalid enum check is not needed here. An assert is the correct behaviour as we should NEVER be using a rule with
    // an invalid condition as it should NEVER have passed the checks when the rule was first stored in createEvent.
    (condition.name, condition.conditionType, condition.constraints) = abi.decode(firstCondition, (string, LEnums.ConditionType,
        bytes));

    if (!runCondition(condition, _rootRegistrationTime, _immutableRulesData, _mutableRulesData, _ticketOwner))
      conditionFailedReason_ = condition.name;
    else if (otherConditions.length != 0)
      conditionFailedReason_ = runConditions(otherConditions, _rootRegistrationTime, _immutableRulesData, _mutableRulesData,
          _ticketOwner);
  }

  function runCondition(Condition memory _condition, uint _rootRegistrationTime, ImmutableRulesData memory _immutableRulesData,
    MutableRulesData memory _mutableRulesData, address _ticketOwner)
    private
    pure
    returns (bool conditionPassed_)
  {
    if (_condition.conditionType == LEnums.ConditionType.TicketGroupMatches) {
      (string memory ticketGroup, bool isEqualTo) = abi.decode(_condition.constraints, (string, bool));
      return checkTicketGroupMatches(ticketGroup, isEqualTo, _immutableRulesData);
    }

    if (_condition.conditionType == LEnums.ConditionType.TicketOwnerIsInWhitelist) {
      bool isInWhitelist = abi.decode(_condition.constraints, (bool));
      return checkTicketOwnerIsInWhitelist(isInWhitelist, _immutableRulesData, _ticketOwner);
    }

    if (_condition.conditionType == LEnums.ConditionType.TransactionTimeIsBetween) {
      (uint lowerBound, uint upperBound) = abi.decode(_condition.constraints, (uint, uint));
      return checkTransactionTimeIsBetween(lowerBound, upperBound, _rootRegistrationTime);
    }

    // The rest of the conditions all check a uint is within a limit.
    uint permittedLimit = abi.decode(_condition.constraints, (uint));

    if (_condition.conditionType == LEnums.ConditionType.NumPermittedResells) {
      return checkNumPermittedResells(permittedLimit, _mutableRulesData);
    }

    if (_condition.conditionType == LEnums.ConditionType.NumPermittedTransfers) {
      return checkNumPermittedTransfers(permittedLimit, _mutableRulesData);
    }

    assert(_condition.conditionType == LEnums.ConditionType.NumPermittedChangesOfOwnership);

    return checkNumPermittedChangesOfOwnership(permittedLimit, _mutableRulesData);
  }

  function checkTransactionTimeIsBetween(uint _lowerBound, uint _upperBound, uint _rootRegistrationTime)
    private
    pure
    returns (bool checkPassed_)
  {
    checkPassed_ = _rootRegistrationTime >=_lowerBound && _rootRegistrationTime <= _upperBound;
  }

  function checkNumPermittedResells(uint _permittedLimit, MutableRulesData memory _mutableRulesData)
    private
    pure
    returns (bool checkPassed_)
  {
    checkPassed_ = _mutableRulesData.numResells <= _permittedLimit;
  }

  function checkNumPermittedTransfers(uint _permittedLimit, MutableRulesData memory _mutableRulesData)
    private
    pure
    returns (bool checkPassed_)
  {
    checkPassed_ = _mutableRulesData.numTransfers <= _permittedLimit;
  }

  function checkNumPermittedChangesOfOwnership(uint _permittedLimit, MutableRulesData memory _mutableRulesData)
    private
    pure
    returns (bool checkPassed_)
  {
    checkPassed_ = _mutableRulesData.numResells + _mutableRulesData.numTransfers <= _permittedLimit;
  }

  function checkTicketGroupMatches(string memory _ticketGroup, bool _isEqualTo, ImmutableRulesData memory _immutableRulesData)
    private
    pure
    returns (bool checkPassed_)
  {
    string memory actualTicketGroup = _immutableRulesData.ticketGroup;
    bytes32 actualTicketGroupHash = keccak256(bytes(actualTicketGroup));
    bytes32 expectedTicketGroupHash = keccak256(bytes(_ticketGroup));
    checkPassed_ = (_isEqualTo == (actualTicketGroupHash == expectedTicketGroupHash));
  }

  function checkTicketOwnerIsInWhitelist(bool _isInWhitelist, ImmutableRulesData memory _immutableRulesData,
      address _ticketOwner)
    private
    pure
    returns (bool checkPassed_)
  {
    uint index = _immutableRulesData.whitelist.length;
    bool found;
    while (!found && index != 0) {
      found = _ticketOwner == _immutableRulesData.whitelist[--index];
    }
    checkPassed_ = (found == _isInWhitelist);
  }
}