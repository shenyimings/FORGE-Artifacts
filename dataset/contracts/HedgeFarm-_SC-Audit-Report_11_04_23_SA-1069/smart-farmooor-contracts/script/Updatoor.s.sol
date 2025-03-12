// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Deployer.s.sol";

contract Updatoor is Deployer {

    function run() external override {
        // Load data and set components needed for the deployment
        // BASE_TOKEN_NAME, TIMELOCK, OWNER, and MANAGER must be set in .env
        loadData();
        setDex();
        setTimelock();

        // Fetch and set components that have been already deployed
        // [TOKEN]_SMART_FARMOOOR, DEX AND TIMELOCK must be set in .env
        fetchAddresses(SMART_FARMOOOR_ADDRESS);

        // explicitly set the values for active modules, by default they are set to current on chain values of SmartFarmooor fetched using fetchAddresses()
        STARGATE_ACTIVE = STARGATE_ACTIVE_CURRENT_VALUE;
        BENQI_ACTIVE = BENQI_ACTIVE_CURRENT_VALUE;
        BANKER_JOE_ACTIVE = BANKER_JOE_ACTIVE_CURRENT_VALUE;
        AAVE_ACTIVE = AAVE_ACTIVE_CURRENT_VALUE;

        setSmartFarmooor();
        
        // deploy and set up contracts
        vm.startBroadcast();

        // ... deployment and after deployment function calls

        vm.stopBroadcast();

        // check that the contract have been correctly deployed and initialized
        verifySmartFarmooor(address(timelock));

        // print the addresses of the components
        printComponentAddresses();

        // print the storage of the components
        printBankerJoeStorage();
    }
}