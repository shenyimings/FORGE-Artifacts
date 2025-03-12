// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IOracle } from  "../src/interfaces/IOracle.sol";

import { Vault } from  "../src/Vault.sol";
import { ChainLinkOracle } from  "../src/ChainLinkOracle.sol";
import { FakeOracle } from  "../test/helpers/FakeOracle.sol";

import { BaseScript } from "./BaseScript.sol";

contract DeployScript is BaseScript {
    using SafeERC20 for IERC20;

    Vault public vault;
    IOracle public oracle;

    function run() public {
        init();

        vm.startBroadcast(pk);

        oracle = new ChainLinkOracle(ethPriceFeed);
        /* oracle = new FakeOracle(); */
        /* oracle.setPrice(1611_00000000); */

        vault = new Vault("ETH @ 1600",
                          "1600",
                          1600_00000000,
                          stEth,
                          address(oracle));

        vm.stopBroadcast();

        {
            string memory objName = string.concat("deploy");
            string memory json;

            json = vm.serializeAddress(objName, "address_oracle", address(oracle));
            json = vm.serializeAddress(objName, "address_vault", address(vault));
            json = vm.serializeAddress(objName, "address_yToken", address(vault.yToken()));
            json = vm.serializeAddress(objName, "address_hodlToken", address(vault.hodlToken()));

            json = vm.serializeString(objName, "contractName_oracle", "IOracle");
            json = vm.serializeString(objName, "contractName_vault", "Vault");
            json = vm.serializeString(objName, "contractName_yToken", "YToken");
            json = vm.serializeString(objName, "contractName_hodlToken", "HodlToken");

            vm.writeJson(json, string.concat("./json/deploy-eth.",
                                             vm.envString("NETWORK"),
                                             ".json"));
        }
     }
}
