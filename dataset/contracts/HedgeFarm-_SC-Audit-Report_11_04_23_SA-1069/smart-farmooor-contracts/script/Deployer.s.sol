// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./deployer/TimelockDeployer.s.sol";
import "./deployer/DexDeployer.s.sol";
import "./deployer/SmartFarmooorDeployer.s.sol";
import "./deployer/NativeGatewayDeployer.s.sol";
import "./deployer/StargateDeployer.s.sol";
import "./deployer/BenqiDeployer.s.sol";
import "./deployer/BankerJoeDeployer.s.sol";
import "./deployer/AaveDeployer.s.sol";

contract Deployer is TimelockDeployer, DexDeployer, SmartFarmooorDeployer, NativeGatewayDeployer, StargateDeployer, BenqiDeployer, BankerJoeDeployer, AaveDeployer {

    function run() external virtual {
        // Load data needed for the deployment
        // BASE_TOKEN_NAME, TIMELOCK, OWNER, and MANAGER must be set in .env
        loadData();
        setDex();
        setTimelock();

        // Set to true to deploy a new dex or a new timelock
        // If set to true, it overrides the fetched and set dex and timelock above
        bool doDex = false;
        bool doTimelock = false;
        bool doNativeGateway = false;

        // deploy and setup the contracts
        vm.startBroadcast();
        deployAll(doDex, doTimelock, doNativeGateway, PRIVATE_DEPLOYMENT_ROLE_ACCOUNTS);
        addAllModules();
        setModuleAllocation();
        smartFarmooor.unpause();
        transferAllOwnership(doDex, doNativeGateway);
        renounceAllRoles(DEPLOYER);
        vm.stopBroadcast();

        // check that the contract have been correctly deployed and initialized
        verifyAll(doDex, doNativeGateway);

        // print the addresses of the components
        printComponentAddresses();
        
        // print the storage of the components
        printComponentStorage();
    }

    // used only by ProposalChecker when we have addresses fetched from on-chain data
    function setAll() internal {
        setTimelock();
        setDex();
        setSmartFarmooorImpl();
        setSmartFarmooor();
        // TODO: set native gateway
        if (STARGATE_ACTIVE) {
            setStargateYieldModuleImpl();
            setStargateYieldModule();
        }
        if (BENQI_ACTIVE) {
            setBenqiYieldModuleImpl();
            setBenqiYieldModule();
        }
        if (BANKER_JOE_ACTIVE) {
            setBankerJoeYieldModuleImpl();
            setBankerJoeYieldModule();
        }
        if (AAVE_ACTIVE) {
            setAaveYieldModuleImpl();
            setAaveYieldModule();
        }
    }
    
    function deployAll(bool doDex, bool doTimelock, bool doNativeGateway, address[] memory privateAccessAccounts) internal {
        // When we have a dex in prod we maybe don't want to deploy it again.
        // However we have to add the new routes manually through the multisig.
        if (doTimelock) {
            deployTimelock();
        }
        if (doDex) {
            deployDex();
        }
        deploySmartFarmooorImpl();
        deploySmartFarmooor(address(timelock), privateAccessAccounts);
        if (doNativeGateway) {
            deployNativeGateway(address(smartFarmooor));
        }
        if (STARGATE_ACTIVE) {
            deployStargateYieldModuleImpl();
            deployStargateYieldModule(address(smartFarmooor), address(dex));
        }
        if (BENQI_ACTIVE) {
            deployBenqiYieldModuleImpl();
            deployBenqiYieldModule(address(smartFarmooor), address(dex));
        }
        if (BANKER_JOE_ACTIVE) {
            deployBankerJoeYieldModuleImpl();
            deployBankerJoeYieldModule(address(smartFarmooor), address(dex));
        }
        if (AAVE_ACTIVE) {
            deployAaveYieldModuleImpl();
            deployAaveYieldModule(address(smartFarmooor), address(dex));
        }
    }

    function addAllModules() internal {
        if (STARGATE_ACTIVE) {
            addStargateToSmartFarmooor(stargateYieldModule);
        }
        if (BENQI_ACTIVE) {
            addBenqiToSmartFarmooor(benqiYieldModule);
        }
        if (BANKER_JOE_ACTIVE) {
            addBankerJoeToSmartFarmooor(bankerJoeYieldModule);
        }
        if (AAVE_ACTIVE) {
            addAaveToSmartFarmooor(aaveYieldModule);
        }
    }

    function transferAllOwnership(bool doDex, bool doNativeGateway) internal {
        if (doDex) {
            transferOwnershipDex(address(timelock));
        }
        // Ownership of the smartFarmoor set at init
        if (doNativeGateway) {
            transferOwnershipNativeGateway(address(timelock));
        }
        if (STARGATE_ACTIVE) {
            transferOwnershipStargateYieldModule(address(timelock));
        }
        if (BENQI_ACTIVE) {
            transferOwnershipBenqiYieldModule(address(timelock));
        }
        if (BANKER_JOE_ACTIVE) {
            transferOwnershipBankerJoeYieldModule(address(timelock));
        }
        if (AAVE_ACTIVE) {
            transferOwnershipAaveYieldModule(address(timelock));
        }
    }

    function verifyAll(bool doDex, bool doNativeGateway) internal {
        verifyTimelock();
        if (doDex) {
            verifyDex(address(timelock));
        }
        verifySmartFarmooor(address(timelock));
        if (doNativeGateway) {
            verifyNativeGateway(address(timelock), address(smartFarmooor));
        }
        if (STARGATE_ACTIVE) {
            verifyStargateYieldModule(address(timelock), address(smartFarmooor), address(dex));
        }
        if (BENQI_ACTIVE) {
            verifyBenqiYieldModule(address(timelock), address(smartFarmooor), address(dex));
        }
        if (BANKER_JOE_ACTIVE) {
            verifyBankerJoeYieldModule(address(timelock), address(smartFarmooor), address(dex));
        }
        if (AAVE_ACTIVE) {
            verifyAaveYieldModule(address(timelock), address(smartFarmooor), address(dex));
        }
    }

    function printComponentAddresses() internal view {
        console2.log(
            "------------------------------------------------------------------------------------------------"
        );
        console2.log("Deployer address:                     ", DEPLOYER);
        console2.log("Owner (Multisig) address:             ", OWNER);
        console2.log("Manager (Multisig) address:           ", MANAGER);
        console2.log("Timelock address:                     ", address(timelock));
        console2.log("Dex address:                          ", address(dex));
        console2.log(
            "Smart farmooor impl address:          ",
            address(smartFarmooorImpl)
        );
        console2.log(
            "Smart farmooor address:               ",
            address(smartFarmooor)
        );
        console2.log("Native gateway:                       ", address(nativeGateway));
        console2.log(
            "Stargate yield module impl address:   ",
            address(stargateYieldModuleImpl)
        );
        console2.log(
            "Stargate yield module address:        ",
            address(stargateYieldModule)
        );
        console2.log(
            "Benqi yield module impl address:      ",
            address(benqiYieldModuleImpl)
        );
        console2.log(
            "Benqi yield module address:           ",
            address(benqiYieldModule)
        );
        console2.log(
            "Banker joe yield module impl address: ",
            address(bankerJoeYieldModuleImpl)
        );
        console2.log(
            "Banker joe yield module address:      ",
            address(bankerJoeYieldModule)
        );
        console2.log(
            "Aave yield module impl address:       ",
            address(aaveYieldModuleImpl)
        );
        console2.log(
            "Aave yield module address:            ",
            address(aaveYieldModule)
        );
        console2.log(
            "------------------------------------------------------------------------------------------------"
        );
    }

    function printComponentStorage() internal view {
        if(address(dex) != address(0)) {
            printDexStorage();
        }
        if(address(smartFarmooor) != address(0)) {
            printSmartFarmooorStorage();
        }
        if(address(nativeGateway) != address(0)) {
            printNativeGatewayStorage();
        }
        if(address(stargateYieldModule) != address(0)) {
            printStargateStorage();
        }
        if(address(benqiYieldModule) != address(0)) {
            printBenqiStorage();
        }
        if(address(bankerJoeYieldModule) != address(0)) {
            printBankerJoeStorage();
        }
        if(address(aaveYieldModule) != address(0)) {
            printAaveStorage();
        }
    }
}
