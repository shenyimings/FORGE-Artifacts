// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { MoneyMarketForTest } from "src/MoneyMarketForTest.sol";

contract SetBorrowerScript is BaseScript {
  function run() public {
    address _borrower = bank;

    vm.startBroadcast(deployerPrivateKey);

    MoneyMarketForTest(moneyMarket).setBorrower(_borrower);

    vm.stopBroadcast();
  }
}
