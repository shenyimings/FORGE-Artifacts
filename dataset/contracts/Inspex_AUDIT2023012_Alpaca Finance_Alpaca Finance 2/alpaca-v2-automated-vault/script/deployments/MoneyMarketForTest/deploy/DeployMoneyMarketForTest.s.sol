// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { MoneyMarketForTest } from "src/MoneyMarketForTest.sol";

contract DeployMoneyMarketForTestScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    address moneyMarketForTest = address(new MoneyMarketForTest());

    vm.stopBroadcast();

    _writeJson(vm.toString(moneyMarketForTest), ".dependencies.moneyMarket");
  }
}
