pragma solidity ^0.8.0;

import "./CommonData.s.sol";
import "./TokenData.s.sol";

contract BtcbData is CommonData, TokenData {

    function loadBtcbData(address feeManager) public {
        // Common
        BASE_TOKEN = BTCB;
        BASE_TOKEN_ORACLE = CHAINLINK_BTC;
        WRAPPED_NATIVE_TOKEN = WAVAX;

        // Active module
        STARGATE_ACTIVE = false;
        BENQI_ACTIVE = true;
        BANKER_JOE_ACTIVE = false;
        AAVE_ACTIVE = true;

        // Allocation
        STARGATE_ALLOCATION = 0;
        BENQI_ALLOCATION = 5700;
        BANKER_JOE_ALLOCATION = 0;
        AAVE_ALLOCATION = 4300;

        // Smart farmooor
        SM_NAME = "HedgeFarm Smart Farmooor BTC.b";
        SM_SYMBOL = "hfSFbtcb";
        SM_FEE_MANAGER = feeManager;
        SM_MIN_HARVEST_THRESHOLD_IN_BASE_TOKEN = 50000; // 0.0005 BTC.b ~10 USD
        SM_PERFORMANCE_FEE = 2000;
        SM_CAP = 2500000000; // 25 BTC.b ~= 530k USD
        SM_MIN_AMOUNT = 60000; // 0.0006 BTC.b ~12.5 USD

        // Benqi
        BENQI_EXECUTION_FEE = 0;
        BENQI_TOKEN = BENQI_BTCB;
        BENQI_YIELD_MODULE_NAME = "BenqiYieldModule";

        // Banker Joe
        BANKER_JOE_EXECUTION_FEE = 0;
        BANKER_JOE_TOKEN = BANKER_JOE_BTCB;
        BANKERJOE_YIELD_MODULE_NAME = "BankerJoeYieldModule";

        // Aave
        AAVE_EXECUTION_FEE = 0;
        AAVE_A_TOKEN = AAVE_A_BTCB;
        AAVE_YIELD_MODULE_NAME = "AaveV3YieldModule";
    }
}
