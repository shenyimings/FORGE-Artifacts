// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { NPVSwap } from  "dlx/src/core/NPVSwap.sol";
import { YieldSlice } from  "dlx/src/core/YieldSlice.sol";
import { IYieldSource } from  "dlx/src/interfaces/IYieldSource.sol";

/* import { VaultFactory, TimeLock } from "y2k-earthquake/src/legacy_v1/VaultFactory.sol"; */
/* import { Controller } from "y2k-earthquake/src/legacy_v1/Controller.sol";  */
/* import { Vault } from "y2k-earthquake/src/legacy_v1/Vault.sol"; */
/* import { FakeOracle } from "y2k-earthquake/test/oracles/FakeOracle.sol"; */
import { VaultV2 } from "y2k-earthquake/src/v2/VaultV2.sol";

import { IInsuranceProvider } from "../src/interfaces/IInsuranceProvider.sol";
import { SelfInsuredVault } from "../src/vaults/SelfInsuredVault.sol";
import { Y2KEarthquakeV2InsuranceProvider } from "../src/providers/Y2KEarthquakeV2InsuranceProvider.sol";

import { BaseScript } from "./BaseScript.sol";

contract DeployFakeSelfInsuredVaultScript is BaseScript {
    using stdJson for string;

    NPVSwap npvSwap;

    address public hedge;
    address public risk;

    Y2KEarthquakeV2InsuranceProvider public provider;
    SelfInsuredVault public vault;
    VaultV2 y2kVault;
    VaultV2 y2kCounterpartyVault;

    uint256 public constant STRIKE = 1000000000000000000;
    address public constant USDC_TOKEN = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    function setUp() public {
        init();
    }

    function run() public {
        console.log("DeploySelfInsuredVaultsScript");

        vm.startBroadcast(pk);
        string memory config;
        if (eq(vm.envString("NETWORK"), "arbitrum")) {
            config = vm.readFile("json/dlx-config.arbitrum.json");
        } else {
            config = vm.readFile("json/dlx-config.localhost.json");
        }

        npvSwap = NPVSwap(vm.parseJsonAddress(config, ".fakeglp_npvSwap.address"));

        console.log("Deploying with npvSwap", address(npvSwap));
        console.log("Deploying with slice  ", address(npvSwap.slice()));
        console.log("Deploying with source ", address(YieldSlice(npvSwap.slice()).yieldSource()));
        IYieldSource vaultSource = YieldSlice(npvSwap.slice()).yieldSource();

        y2kVault = new VaultV2(false,
                               address(vaultSource.yieldToken()),
                               "Vault",
                               "v",
                               "randomURI",
                               USDC_TOKEN,
                               STRIKE,
                               deployerAddress);
        y2kCounterpartyVault = new VaultV2(false,
                                           address(vaultSource.yieldToken()),
                                           "Vault",
                                           "v",
                                           "randomURI",
                                           USDC_TOKEN,
                                           STRIKE,
                                           deployerAddress);
        y2kVault.setCounterPartyVault(address(y2kCounterpartyVault));

        uint40 begin = uint40(block.timestamp);
        helperSetEpoch(begin, begin + 1 days, 100);
        helperSetEpoch(begin + 1 days, begin + 2 days, 101);
        helperSetEpoch(begin + 2 days, begin + 3 days, 102);
        helperSetEpoch(begin + 3 days, begin + 4 days, 103);

        vault = new SelfInsuredVault("Self Insured fakeGLP Vault",
                                     "sivFakeGLP",
                                     address(vaultSource.yieldToken()),
                                     address(vaultSource),
                                     address(npvSwap));

        provider = new Y2KEarthquakeV2InsuranceProvider(address(y2kVault), address(vault));

        // Set the provider
        vault.addInsuranceProvider(IInsuranceProvider(provider), 10_00);

        vm.stopBroadcast();

        {
            string memory objName = "deploy";
            string memory json;
            json = vm.serializeAddress(objName, "address_siv", address(vault));
            json = vm.serializeString(objName, "contractName_siv", "SelfInsuredVault");

            string memory filename = "./json/deploy_fakevault";
            if (eq(vm.envString("NETWORK"), "arbitrum")) {
                filename = string.concat(filename, ".arbitrum.json");
            } else {
                filename = string.concat(filename, ".localhost.json");
            }

            vm.writeJson(json, filename);
        }
    }

    function helperSetEpoch(uint40 _epochBegin, uint40 _epochEnd, uint256 _epochId) public {
        y2kVault.setEpoch(_epochBegin, _epochEnd, _epochId);
        y2kCounterpartyVault.setEpoch(_epochBegin, _epochEnd, _epochId);
    }
}
