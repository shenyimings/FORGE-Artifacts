pragma solidity ^0.8.0;

import "./CommonData.s.sol";
import "./TokenData.s.sol";

contract UsdtData is CommonData, TokenData {

    function loadUsdtData(address feeManager) public {
        // Common
        BASE_TOKEN = USDT;
        BASE_TOKEN_ORACLE = CHAINLINK_USDT;
        WRAPPED_NATIVE_TOKEN = WAVAX;

        // Active module
        STARGATE_ACTIVE = true;
        BENQI_ACTIVE = true;
        BANKER_JOE_ACTIVE = true;
        AAVE_ACTIVE = true;

        // Allocation
        STARGATE_ALLOCATION = 6000;
        BENQI_ALLOCATION = 1000;
        BANKER_JOE_ALLOCATION = 2000;
        AAVE_ALLOCATION = 1000;

        // Smart farmooor
        SM_NAME = "HedgeFarm Smart Farmooor USDT";
        SM_SYMBOL = "hfSFusdt";
        SM_FEE_MANAGER = feeManager;
        SM_MIN_HARVEST_THRESHOLD_IN_BASE_TOKEN = 50000; // 1 USDC
        SM_PERFORMANCE_FEE = 2000;
        SM_CAP = 500000000000; // 500k USDT
        SM_MIN_AMOUNT = 10000000; // 10 USDT ~= 10 USD

        // Stargate
        STARGATE_EXECUTION_FEE = 300000000000000000;
        STARGATE_POOL = STARGATE_USDT_POOL;
        STARGATE_ROUTER_POOL_ID = STARGATE_ROUTER_USDT_POOL_ID;
        STARGATE_LP_STAKING_POOL_ID = STARGATE_LP_STAKING_USDT_POOL_ID;
        STARGATE_REDEEM_FROM_CHAIN_ID = 110;
        STARGATE_LP_PROFIT_WITHDRAWL_THRESHOLD_IN_BASE_TOKEN = 1000000; // 1 USDC
        STARGATE_YIELD_MODULE_NAME = "StargateYieldModule";

        // Benqi
        BENQI_EXECUTION_FEE = 0;
        BENQI_TOKEN = BENQI_USDT;
        BENQI_YIELD_MODULE_NAME = "BenqiYieldModule";

        // Banker Joe
        BANKER_JOE_EXECUTION_FEE = 0;
        BANKER_JOE_TOKEN = BANKER_JOE_USDT;
        BANKERJOE_YIELD_MODULE_NAME = "BankerJoeYieldModule";

        // Aave
        AAVE_EXECUTION_FEE = 0;
        AAVE_A_TOKEN = AAVE_A_USDT;
        AAVE_YIELD_MODULE_NAME = "AaveV3YieldModule";
    }
}
