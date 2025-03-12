pragma solidity ^0.8.0;

import "./CommonData.s.sol";
import "./TokenData.s.sol";

contract WavaxData is CommonData, TokenData {

    function loadWavaxData(address feeManager) public {
        // Common
        BASE_TOKEN = WAVAX;
        BASE_TOKEN_ORACLE = CHAINLINK_AVAX;
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
        SM_NAME = "HedgeFarm Smart Farmooor WAVAX";
        SM_SYMBOL = "hfSFwavax";
        SM_FEE_MANAGER = feeManager;
        SM_MIN_HARVEST_THRESHOLD_IN_BASE_TOKEN = 3000000000000000;
        SM_PERFORMANCE_FEE = 2000;
        SM_CAP = 25000000000000000000000; // 25k AVAX ~= 500k USD
        SM_MIN_AMOUNT = 200000000000000000; // 0.2 AVAX ~= 10 USD

        // Benqi
        BENQI_EXECUTION_FEE = 0;
        BENQI_TOKEN = BENQI_AVAX;
        BENQI_YIELD_MODULE_NAME = "BenqiYieldModule";

        // Aave
        AAVE_EXECUTION_FEE = 0;
        AAVE_A_TOKEN = AAVE_A_WAVAX;
        AAVE_YIELD_MODULE_NAME = "AaveV3YieldModule";
    }
}
