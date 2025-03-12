// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library Errors {
    // number code
    uint16 public constant NO_ERROR_CODE = 0;

    // settings/acl
    string public constant ACL_ONLY_ADDRESS_ADMIN_CAN_CALL = 'ACL_ONLY_ADDRESS_ADMIN_CAN_CALL';
    string public constant ACL_ONLY_GOVERNANCE_CAN_CALL = 'ACL_ONLY_GOVERNANCE_CAN_CALL';
    string public constant ACL_ONLY_EMERGENCY_ADMIN_CAN_CALL = 'ACL_ONLY_EMERGENCY_ADMIN_CAN_CALL';
    string public constant ACL_ONLY_POOL_ADMIN_CAN_CALL = 'ACL_ONLY_POOL_ADMIN_CAN_CALL';
    string public constant ACL_ONLY_LIQUIDATOR_CAN_CALL = 'ACL_ONLY_LIQUIDATOR_CAN_CALL';
    string public constant ACL_ONLY_LIQUIDATION_OPERATOR_CAN_CALL = 'ACL_ONLY_LIQUIDATION_OPERATOR_CAN_CALL';
    string public constant ACL_ONLY_AIRDROP_OPERATOR_CAN_CALL = 'ACL_ONLY_AIRDROP_OPERATOR_CAN_CALL';
    string public constant ACL_ONLY_POOL_CAN_CALL = 'ACL_ONLY_POOL_CAN_CALL';

    // math
    string public constant MATH_MULTIPLICATION_OVERFLOW = '1';
    string public constant MATH_ADDITION_OVERFLOW = '2';
    string public constant MATH_DIVISION_BY_ZERO = '3';
    
    //deposit
    string public constant DEPOSIT_AMOUNT_SHOULD_BE_BIGGER_THAN_ZERO = 'DEPOSIT_AMOUNT_SHOULD_BE_BIGGER_THAN_ZERO';

    // withdraw
    string public constant WITHDRAW_AMOUNT_NOT_ALLOWED = 'WITHDRAW_AMOUNT_NOT_ALLOWED';
    string public constant WITHDRAW_LIQUIDITY_NOT_SUFFIENCE = 'WITHDRAW_LIQUIDITY_NOT_SUFFIENCE';

    // borrow
    string public constant BORROW_DURATION_NOT_ALLOWED = 'BORROW_DURATION_NOT_ALLOWED';
    string public constant BORROW_AMOUNT_EXCEED_BORROW_LIMIT = 'BORROW_AMOUNT_EXCEED_BORROW_LIMIT';

    // repay
    string public constant REPAY_STATUS_ERROR = 'REPAY_STATUS_ERROR';
    string public constant REPAY_AMOUNT_NOT_ENOUGH = 'REPAY_AMOUNT_NOT_ENOUGH';

    // extend
    string public constant EXTEND_STATUS_ERROR = 'EXTEND_LOAN_STATUS_ERROR';
    string public constant EXTEND_MSG_VALUE_ERROR = 'EXTEND_MSG_VALUE_ERROR';

    // liquidate
    string public constant START_LIQUIDATION_STATUS_ERROR = 'START_LIQUIDATION_STATUS_ERROR';
    string public constant END_LIQUIDATION_STATUS_ERROR = 'END_LIQUIDATION_STATUS_ERROR';
    string public constant END_LIQUIDATION_AMOUNT_ERROR = 'END_LIQUIDATION_AMOUNT_ERROR';

    // loan
    string public constant LOAN_SET_STATUS_ERROR = 'LOAN_SET_STATUS_ERROR';
    string public constant LOAN_REPAYER_IS_NOT_OWNER = 'LOAN_REPAYER_IS_NOT_OWNER';
    string public constant LOAN_LIQUIDATING_STATUS_CAN_NOT_BE_UPDATED = 'LOAN_LIQUIDATING_STATUS_CAN_NOT_BE_UPDATED';
    string public constant LOAN_CALLER_IS_NOT_OWNER = 'LOAN_CALLER_IS_NOT_OWNER';
    string public constant LOAN_IS_END = 'LOAN_IS_END';
    string public constant FLASHLOAN_EXECUTOR_ERROR = 'FLASHLOAN_EXECUTOR_ERROR';
    string public constant FLASHLOAN_STATUS_ERROR = 'FLASHLOAN_STATUS_ERROR';

    // money market
    string public constant MONEY_MARKET_DEPOSIT_AMOUNT_ALLOWED = 'MONEY_MARKET_DEPOSIT_AMOUNT_ALLOWED';
    string public constant MONEY_MARKET_WITHDRAW_AMOUNT_NOT_ALLOWED = 'MONEY_MARKET_WITHDRAW_AMOUNT_NOT_ALLOWED';
    string public constant MONEY_MARKET_APPROVAL_FAILED = 'MONEY_MARKET_APPROVAL_FAILED';
    string public constant MONEY_MARKET_DELEGATE_CALL_ERROR = 'MONEY_MARKET_DELEGATE_CALL_ERROR';

    // price oracle
    string public constant PRICE_ORACLE_ROUND_INTERVAL_CAN_NOT_BE_0 = 'PRICE_ORACLE_ROUND_INTERVAL_CAN_NOT_BE_0';
    string public constant PRICE_ORACLE_HAS_NO_PRICE_FEED = 'PRICE_ORACLE_HAS_NO_PRICE_FEED';
    string public constant PRICE_ORACLE_INCORRECT_TIMESTAMP = 'PRICE_ORACLE_INCORRECT_TIMESTAMP';
    string public constant PRICE_ORACLE_PARAMS_ERROR = 'PRICE_ORACLE_PARAMS_ERROR';

    // reserve
    string public constant RESERVE_LIQUIDITY_INSUFFICIENT = 'RESERVE_LIQUIDITY_INSUFFICIENT';
    string public constant RESERVE_DOES_NOT_EXISTS = 'RESERVE_DOES_NOT_EXISTS';
    string public constant RESERVE_INDEX_OVERFLOW = 'RESERVE_INDEX_OVERFLOW';

    // token
    string public constant AMOUNT_SCALED_IS_ZERO = 'AMOUNT_SCALED_IS_ZERO';
    string public constant AMOUNT_TRANSFER_OWERFLOW = 'AMOUNT_TRANSFER_OWERFLOW';


    string public constant ETH_TRANSFER_FAILED = 'ETH_TRANSFER_FAILED';
    string public constant RECEIVE_NOT_ALLOWED = 'RECEIVE_NOT_ALLOWED';
    string public constant FALLBACK_NOT_ALLOWED = 'FALLBACK_NOT_ALLOWED';
}
