// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { MoneyMarketForTest } from "src/MoneyMarketForTest.sol";

contract WithdrawTokensScript is BaseScript {
  function run() public {
    address[] memory _tokens = new address[](2);
    _tokens[0] = usdt;
    _tokens[1] = wbnb;

    vm.startBroadcast(deployerPrivateKey);

    MoneyMarketForTest(moneyMarket).withdrawTokens(_tokens);

    vm.stopBroadcast();
  }
}
