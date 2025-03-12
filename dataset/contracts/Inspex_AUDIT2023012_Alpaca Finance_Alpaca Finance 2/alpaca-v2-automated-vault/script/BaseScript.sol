// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Script.sol";

contract BaseScript is Script {
  using stdJson for string;

  string internal configFilePath =
    string.concat(vm.projectRoot(), string.concat("/", vm.envString("DEPLOYMENT_CONFIG_FILENAME")));
  string internal configJson = vm.readFile(configFilePath);
  uint256 internal deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
  address internal deployerAddress = vm.addr(deployerPrivateKey);

  // Miscellanous
  address internal proxyAdmin;
  address internal performanceFeeBucket;

  // Automated vault
  address internal automatedVaultERC20Implementation;
  address internal automatedVaultManager;
  address internal bank;
  address internal pancakeV3VaultOracle;
  address internal avManagerV3Gateway;

  // Dependencies
  address internal moneyMarket;
  address internal pancakeV3PositionManager;
  address internal pancakeV3Router;
  address internal pancakeV3MasterChef;
  address internal zapV3;

  // Tokens
  address internal wbnb;
  address internal usdt;
  address internal cake;

  // Pancake v3 pools
  address internal pancakeV3USDTWBNB500Pool;

  constructor() {
    // Miscellanous
    proxyAdmin = abi.decode(configJson.parseRaw(".proxyAdmin"), (address));
    performanceFeeBucket = abi.decode(configJson.parseRaw(".performanceFeeBucket"), (address));
    // Automated vault
    automatedVaultERC20Implementation =
      abi.decode(configJson.parseRaw(".automatedVault.automatedVaultERC20Implementation"), (address));
    automatedVaultManager = abi.decode(configJson.parseRaw(".automatedVault.automatedVaultManager.proxy"), (address));
    bank = abi.decode(configJson.parseRaw(".automatedVault.bank.proxy"), (address));
    pancakeV3VaultOracle =
      abi.decode(configJson.parseRaw(".automatedVault.pancake-v3-vault.vaultOracle.proxy"), (address));
    avManagerV3Gateway = abi.decode(configJson.parseRaw(".automatedVault.avManagerV3Gateway"), (address));
    // Dependencies
    moneyMarket = abi.decode(configJson.parseRaw(".dependencies.moneyMarket"), (address));
    pancakeV3PositionManager = abi.decode(configJson.parseRaw(".dependencies.pancake-v3.positionManager"), (address));
    pancakeV3Router = abi.decode(configJson.parseRaw(".dependencies.pancake-v3.swapRouter"), (address));
    pancakeV3MasterChef = abi.decode(configJson.parseRaw(".dependencies.pancake-v3.masterChef"), (address));
    zapV3 = abi.decode(configJson.parseRaw(".dependencies.zapV3"), (address));
    // Tokens
    wbnb = abi.decode(configJson.parseRaw(".tokens.wbnb"), (address));
    usdt = abi.decode(configJson.parseRaw(".tokens.usdt"), (address));
    cake = abi.decode(configJson.parseRaw(".tokens.cake"), (address));
    // Pancake v3 pools
    pancakeV3USDTWBNB500Pool =
      abi.decode(configJson.parseRaw(".dependencies.pancake-v3.pools.usdt-wbnb-500"), (address));
  }

  function _writeJson(string memory serializedJson, string memory path) internal {
    console.log("writing to:", path, "value:", serializedJson);
    serializedJson.write(configFilePath, path);
  }
}
