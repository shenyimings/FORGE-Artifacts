// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { MoneyMarketForTest } from "src/MoneyMarketForTest.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";

contract InjectFundScript is BaseScript {
  function run() public {
    address _token = usdt;
    uint256 _amount = 600 ether;

    vm.startBroadcast(deployerPrivateKey);

    ERC20(_token).approve(moneyMarket, _amount);
    MoneyMarketForTest(moneyMarket).injectFund(_token, _amount);

    vm.stopBroadcast();
  }
}
