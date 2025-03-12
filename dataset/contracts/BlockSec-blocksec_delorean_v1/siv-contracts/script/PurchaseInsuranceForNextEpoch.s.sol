// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { NPVSwap } from  "dlx/src/core/NPVSwap.sol";
import { YieldSlice } from  "dlx/src/core/YieldSlice.sol";
import { IYieldSource } from  "dlx/src/interfaces/IYieldSource.sol";

import { VaultFactory, TimeLock } from "y2k-earthquake/src/legacy_v1/VaultFactory.sol";
import { Controller } from "y2k-earthquake/src/legacy_v1/Controller.sol"; 
import { Vault } from "y2k-earthquake/src/legacy_v1/Vault.sol";

import { IInsuranceProvider } from "../src/interfaces/IInsuranceProvider.sol";
import { SelfInsuredVault } from "../src/vaults/SelfInsuredVault.sol";
import { Y2KEarthquakeV1InsuranceProvider } from "../src/providers/Y2KEarthquakeV1InsuranceProvider.sol";
import { StakedGLPYieldSource } from "../src/sources/StakedGLPYieldSource.sol";

import { BaseScript } from "./BaseScript.sol";

contract PurchaseInsuranceForNextEpoch is BaseScript {
    function setUp() public {
        init();
    }

    function run() public {
        console.log("PurchaseInsuranceForNextEpoch");

        vm.startBroadcast(pk);
        string memory config;
        if (eq(vm.envString("NETWORK"), "arbitrum")) {
            config = vm.readFile("json/config.arbitrum.json");
        } else {
            config = vm.readFile("json/config.localhost.json");
        }

        SelfInsuredVault vault = SelfInsuredVault(vm.parseJsonAddress(config, ".glpvault_siv.address"));

        vault.purchaseInsuranceForNextEpoch(50_00, 1000000);

        vm.stopBroadcast();
    }

}
