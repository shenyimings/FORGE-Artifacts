pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./data/EnvData.s.sol";
import "./data/TestData.s.sol";
import "./data/CommonData.s.sol";
import "./data/TimelockData.s.sol";
import "./data/DexData.s.sol";
import "./data/BtcbData.s.sol";
import "./data/SavaxData.s.sol";
import "./data/UsdtData.s.sol";
import "./data/UsdcData.s.sol";
import "./data/WavaxData.s.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DataLoader is Script, Test, EnvData, TestData, CommonData, TimelockData, DexData, BtcbData, SavaxData, UsdtData, UsdcData, WavaxData {

    /*
    Rules
    - EOA and multisig are stored in capitalized variable, e.g., OWNER, MANAGER, DEPLOYER, etc
    - Contracts are stored in object, even if it already deployed on stage or prod, e.g., timelock, smartFarmooor, dex, etc
    */

    // This function should only used when interacting with prod or stage
    function loadData() public {
        // We check here that the environment variables have been properly set.
        // If one of the variable is the default value (zero, empty string, etc), 
        // it means that the .env is not correctly set.
        require(keccak256(bytes(BASE_TOKEN_NAME)) != keccak256(bytes(string(""))), "BASE_TOKEN_NAME must not be empty");
        require(TIMELOCK != address(0), "TIMELOCK != address(0)");
        require(OWNER != address(0), "OWNER != address(0)");
        require(MANAGER != address(0), "MANAGER != address(0)");
        require(DEPLOYER != address(0), "DEPLOYER != address(0)");
        require(DEX != address(0), "DEX != address(0)");

        _loadData(false);

        require(SMART_FARMOOOR_ADDRESS != address(0), "SMART_FARMOOOR_ADDRESS != address(0)");
    }

    // This function should only be used by tests
    function loadTestData() public {
        require(keccak256(bytes(BASE_TOKEN_NAME)) != keccak256(bytes(string(""))));

        // If needed, the below components are deployed in tests
        TIMELOCK = address(0);
        DEX = address(0);
        BTCB_SMART_FARMOOOR = address(0);
        USDT_SMART_FARMOOOR = address(0);
        USDC_SMART_FARMOOOR = address(0);
        SAVAX_SMART_FARMOOOR = address(0);
        WAVAX_SMART_FARMOOOR = address(0);

        // We override these data when we deploy contract for test such that the addresses are deterministic
        OWNER = makeAddr("OWNER");
        MANAGER = makeAddr("MANAGER");
        DEPLOYER = makeAddr("DEPLOYER");

        _loadData(true);
    }

    function _loadData(bool isTest) private {
        loadTimelockData(OWNER, MANAGER);

        address feeManager = OWNER;
        if (keccak256(bytes(BASE_TOKEN_NAME)) == keccak256(bytes("BTCB"))) {
            require(isTest || BTCB_SMART_FARMOOOR != address(0), "BTCB_SMART_FARMOOOR != address(0)");
            SMART_FARMOOOR_ADDRESS = BTCB_SMART_FARMOOOR;
            loadBtcbData(feeManager);
        }
        if (keccak256(bytes(BASE_TOKEN_NAME)) == keccak256(bytes("SAVAX"))) {
            require(isTest ||SAVAX_SMART_FARMOOOR != address(0), "SAVAX_SMART_FARMOOOR != address(0)");
            SMART_FARMOOOR_ADDRESS = SAVAX_SMART_FARMOOOR;
            loadSavaxData(feeManager);
        }
        if (keccak256(bytes(BASE_TOKEN_NAME)) == keccak256(bytes("USDT"))) {
            require(isTest || USDT_SMART_FARMOOOR != address(0), "USDT_SMART_FARMOOOR != address(0)");
            SMART_FARMOOOR_ADDRESS = USDT_SMART_FARMOOOR;
            loadUsdtData(feeManager);
        }
        if (keccak256(bytes(BASE_TOKEN_NAME)) == keccak256(bytes("USDC"))) {
            require(isTest || USDC_SMART_FARMOOOR != address(0), "USDC_SMART_FARMOOOR != address(0)");
            SMART_FARMOOOR_ADDRESS = USDC_SMART_FARMOOOR;
            loadUsdcData(feeManager);
        }
        if (keccak256(bytes(BASE_TOKEN_NAME)) == keccak256(bytes("WAVAX"))) {
            require(isTest || WAVAX_SMART_FARMOOOR != address(0), "WAVAX_SMART_FARMOOOR != address(0)");
            SMART_FARMOOOR_ADDRESS = WAVAX_SMART_FARMOOOR;
            loadWavaxData(feeManager);
        }
    }
}
