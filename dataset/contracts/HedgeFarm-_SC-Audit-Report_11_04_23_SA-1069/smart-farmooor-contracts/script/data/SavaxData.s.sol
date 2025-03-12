pragma solidity ^0.8.0;

import "./CommonData.s.sol";
import "./TokenData.s.sol";

contract SavaxData is CommonData, TokenData {

    function loadSavaxData(address feeManager) public {
        // Common
        BASE_TOKEN = SAVAX;
        BASE_TOKEN_ORACLE = CHAINLINK_SAVAX;
        WRAPPED_NATIVE_TOKEN = WAVAX;

        // Active module
        STARGATE_ACTIVE = false;
        BENQI_ACTIVE = true;
        BANKER_JOE_ACTIVE = false;
        AAVE_ACTIVE = true;

        // Allocation
        STARGATE_ALLOCATION = 0;
        BENQI_ALLOCATION = 5000;
        BANKER_JOE_ALLOCATION = 0;
        AAVE_ALLOCATION = 5000;

        // Smart farmooor
        SM_NAME = "HedgeFarm Smart Farmooor SAVAX";
        SM_SYMBOL = "hfSFsavax";
        SM_FEE_MANAGER = feeManager;
        SM_MIN_HARVEST_THRESHOLD_IN_BASE_TOKEN = 3000000000000000;
        SM_PERFORMANCE_FEE = 2000;
        SM_CAP = 45000000000000000000000; // 45k sAVAX ~= 500k USD
        SM_MIN_AMOUNT = 750000000000000000; // 0.75 sAVAX ~= 10 USD

        // Benqi
        BENQI_EXECUTION_FEE = 0;
        BENQI_TOKEN = BENQI_SAVAX;
        BENQI_YIELD_MODULE_NAME = "BenqiYieldModule";

        // Aave
        AAVE_EXECUTION_FEE = 0;
        AAVE_A_TOKEN = AAVE_A_SAVAX;
        AAVE_YIELD_MODULE_NAME = "AaveV3YieldModule";
    }
}
