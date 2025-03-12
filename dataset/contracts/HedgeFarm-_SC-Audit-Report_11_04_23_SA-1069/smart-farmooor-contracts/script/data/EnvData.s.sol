pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
This script file reads environment variables if they exist. When run locally, the 
.env file is sourced before the execution of any script so they are always present. 
On the other hand, the github action does not source the .env before running 
the tests because it does not have access to it. In that case the address zero is
set here and then overridden by the DataLoader.
 */

contract EnvData is Script {
    string BASE_TOKEN_NAME = vm.envOr("BASE_TOKEN_NAME", string(""));
    address TIMELOCK = vm.envOr("TIMELOCK_ADDRESS", address(0));
    address OWNER = vm.envOr("OWNER_ADDRESS", address(0));
    address MANAGER = vm.envOr("MANAGER_ADDRESS", address(0));
    address DEPLOYER = vm.envOr("DEPLOYER_ADDRESS", address(0));
    address DEX = vm.envOr("DEX_ADDRESS", address(0));
    address BTCB_SMART_FARMOOOR = vm.envOr("BTCB_SMART_FARMOOOR", address(0));
    address USDT_SMART_FARMOOOR = vm.envOr("USDT_SMART_FARMOOOR", address(0));
    address USDC_SMART_FARMOOOR = vm.envOr("USDC_SMART_FARMOOOR", address(0));
    address SAVAX_SMART_FARMOOOR = vm.envOr("SAVAX_SMART_FARMOOOR", address(0));
    address WAVAX_SMART_FARMOOOR = vm.envOr("WAVAX_SMART_FARMOOOR", address(0));
    address[] PRIVATE_DEPLOYMENT_ROLE_ACCOUNTS = vm.envOr("PRIVATE_DEPLOYMENT_ROLE_ACCOUNTS", ",",  new address[](0));

    address SMART_FARMOOOR_ADDRESS;
}