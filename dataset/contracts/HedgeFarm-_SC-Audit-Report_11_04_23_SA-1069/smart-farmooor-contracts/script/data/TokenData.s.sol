pragma solidity ^0.8.0;

abstract contract TokenData {
    // Common
    address BASE_TOKEN;
    address BASE_TOKEN_ORACLE;
    address WRAPPED_NATIVE_TOKEN;

    // Active module
    bool STARGATE_ACTIVE;
    bool BENQI_ACTIVE;
    bool BANKER_JOE_ACTIVE;
    bool AAVE_ACTIVE;

    // Allocation
    uint256 STARGATE_ALLOCATION;
    uint256 BENQI_ALLOCATION;
    uint256 BANKER_JOE_ALLOCATION;
    uint256 AAVE_ALLOCATION;

    // Smart farmooor
    string SM_NAME;
    string SM_SYMBOL;
    address SM_FEE_MANAGER;
    uint256 SM_MIN_HARVEST_THRESHOLD_IN_BASE_TOKEN;
    uint256 SM_CAP;
    uint256 SM_MIN_AMOUNT;
    uint16 SM_PERFORMANCE_FEE;

    // Stargate
    uint256 STARGATE_EXECUTION_FEE;
    address STARGATE_POOL;
    uint16 STARGATE_ROUTER_POOL_ID;
    uint256 STARGATE_LP_STAKING_POOL_ID;
    uint16 STARGATE_REDEEM_FROM_CHAIN_ID;
    uint256 STARGATE_LP_PROFIT_WITHDRAWL_THRESHOLD_IN_BASE_TOKEN;
    string STARGATE_YIELD_MODULE_NAME;

    // Benqi
    uint256 BENQI_EXECUTION_FEE;
    address BENQI_TOKEN;
    string BENQI_YIELD_MODULE_NAME;

    // Banker Joe
    uint256 BANKER_JOE_EXECUTION_FEE;
    address BANKER_JOE_TOKEN;
    string BANKERJOE_YIELD_MODULE_NAME;

    // Aave
    uint256 AAVE_EXECUTION_FEE;
    address AAVE_A_TOKEN;
    string AAVE_YIELD_MODULE_NAME;
}
