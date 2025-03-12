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

contract DeployFakeSelfInsuredVaultScript is BaseScript {
    using stdJson for string;

    NPVSwap npvSwap;

    Controller public controller;
    VaultFactory public vaultFactory;
    address public hedge;
    address public risk;
    Vault public vHedge;
    Vault public vRisk;

    IInsuranceProvider public provider;
    SelfInsuredVault public vault;

    function setUp() public {
        init();
    }

    function run() public {
        console.log("DeployGLPSelfInsuredVaultsScript");

        vm.startBroadcast(pk);

        /* string memory config; */
        /* if (eq(vm.envString("NETWORK"), "arbitrum")) { */
        /*     config = vm.readFile("json/dlx-config.arbitrum.json"); */
        /* } else { */
        /*     config = vm.readFile("json/dlx-config.localhost.json"); */
        /* } */
        /* npvSwap = NPVSwap(vm.parseJsonAddress(config, ".glp_npvSwap.address")); */
        /* console.log("npvSwap:", address(npvSwap)); */

        /* vaultFactory = VaultFactory(y2kVaultFactory); */
        // Find market indexes in Y2K
        /* uint256 miUSDC = 7; */
        /* uint256 miUSDT = 8; */
        /* uint256 miFrax = 13; */
        /* uint256 miDai = 14; */
        /* for (uint256 i = 1; i < vaultFactory.marketIndex(); i++) { */
        /*     hedge = vaultFactory.getVaults(i)[0]; */
        /*     risk = vaultFactory.getVaults(i)[1]; */

        /*     if (address(Vault(hedge).tokenInsured()) == arbitrumUSDC) { */
        /*         /\* console.log("USDC hedge", hedge, i); *\/ */
        /*         /\* miUSDC = i; *\/ */
        /*     } else if (address(Vault(hedge).tokenInsured()) == arbitrumUSDT) { */
        /*         /\* console.log("USDT hedge", hedge, i); *\/ */
        /*         /\* miUSDT = i; *\/ */
        /*     } else if (address(Vault(hedge).tokenInsured()) == arbitrumFrax) { */
        /*         /\* console.log("Frax hedge", hedge, i); *\/ */
        /*         /\* miFrax = i; *\/ */
        /*     } else if (address(Vault(hedge).tokenInsured()) == arbitrumDai) { */
        /*         /\* console.log("Dai hedge ", hedge, i); *\/ */
        /*         /\* miDai = i; *\/ */
        /*     } */
        /* } */

        /* console.log("miUSDC", miUSDC); */
        /* console.log("miUSDT", miUSDT); */
        /* console.log("miFrax", miFrax); */
        /* console.log("miDai ", miDai); */

        /* console.log("Deploying with npvSwap    ", address(npvSwap)); */
        /* console.log("Deploying with slice      ", address(npvSwap.slice())); */
        /* console.log("Deploying with source     ", address(YieldSlice(npvSwap.slice()).yieldSource())); */
        /* console.log("Deploying with y2k factory", address(vaultFactory)); */
        /* console.log("Deploying with stakedGLP  ", address(stakedGLP)); */
        /* console.log("Deploying with glpTracker ", address(glpTracker)); */

        /* StakedGLPYieldSource source = new StakedGLPYieldSource(address(stakedGLP), */
        /*                                                        arbitrumWeth, */
        /*                                                        address(glpTracker)); */

        /* vault = new SelfInsuredVault("Self Insured GLP Vault", */
        /*                              "sivGLP", */
        /*                              address(source.yieldToken()), */
        /*                              address(source), */
        /*                              address(npvSwap)); */

        /* source.setOwner(address(vault)); */

        /* vault.addInsuranceProvider(providerForIndex(miUSDC, address(vault)), 8_00); */
        /* vault.addInsuranceProvider(providerForIndex(miUSDT, address(vault)),   50); */
        /* vault.addInsuranceProvider(providerForIndex(miDai,  address(vault)), 1_00); */
        /* vault.addInsuranceProvider(providerForIndex(miFrax, address(vault)),   50); */

        /* vault.addRewardToken(y2kToken); */

        vm.stopBroadcast();

        /* { */
        /*     string memory objName = "deploy"; */
        /*     string memory json; */
        /*     json = vm.serializeAddress(objName, "address_vaultFactory", address(vaultFactory)); */
        /*     json = vm.serializeAddress(objName, "address_controller", address(controller)); */
        /*     json = vm.serializeAddress(objName, "address_siv", address(vault)); */

        /*     json = vm.serializeString(objName, "contractName_vaultFactory", "VaultFactory"); */
        /*     json = vm.serializeString(objName, "contractName_controller", "Controller"); */
        /*     json = vm.serializeString(objName, "contractName_siv", "SelfInsuredVault"); */

        /*     string memory filename = "./json/deploy_glpvault"; */
        /*     if (eq(vm.envString("NETWORK"), "arbitrum")) { */
        /*         filename = string.concat(filename, ".arbitrum.json"); */
        /*     } else { */
        /*         filename = string.concat(filename, ".localhost.json"); */
        /*     } */

        /*     vm.writeJson(json, filename); */
        /* } */

    }

    /* function providerForIndex(uint256 marketIndex, address beneficiary) public returns (IInsuranceProvider) { */
    /*     console.log("Looking up vHedge for", marketIndex); */
    /*     vHedge = Vault(vaultFactory.getVaults(marketIndex)[0]); */
    /*     console.log("Got", address(vHedge)); */

    /*     provider = IInsuranceProvider(new Y2KEarthquakeV1InsuranceProvider(address(vHedge), beneficiary)); */

    /*     console.log("Next epoch", provider.nextEpoch()); */
    /*     console.log("Next epoch purch", provider.isNextEpochPurchasable()); */

    /*     return provider; */
    /* } */
}
