pragma solidity 0.5.12;

library LEnums {

  enum ConditionType {
    TransactionTimeIsBetween,
    NumPermittedResells,
    NumPermittedTransfers,
    NumPermittedChangesOfOwnership,
    TicketGroupMatches,
    TicketOwnerIsInWhitelist,
    INVALID
  }

  enum TransactionType {
    Sell,
    Resell,
    Transfer,
    Cancel,
    Redeem,
    Update,
    INVALID
  }

  function validateConditionType(uint _conditionTypeAsUint)
    internal
    pure
    returns(ConditionType conditonType_)
  {
    require(_conditionTypeAsUint < uint(ConditionType.INVALID), "Could not decode invalid condition type");
    conditonType_ = ConditionType(_conditionTypeAsUint);
  }

  function validateTransactionType(uint _transactionTypeAsUint)
    internal
    pure
    returns(TransactionType transactionType_)
  {
    require(_transactionTypeAsUint < uint(TransactionType.INVALID), "Could not decode invalid transaction type");
    transactionType_ = TransactionType(_transactionTypeAsUint);
  }
}