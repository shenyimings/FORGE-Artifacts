// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { MoneyMarketForTest } from "src/MoneyMarketForTest.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";

contract InjectFundScript is BaseScript {
  function run() public {
    uint256 _interestRatePerSec = 2536783358; // 8% per year;

    vm.startBroadcast(deployerPrivateKey);

    MoneyMarketForTest(moneyMarket).setInterestRatePerSec(_interestRatePerSec);

    vm.stopBroadcast();
  }
}
