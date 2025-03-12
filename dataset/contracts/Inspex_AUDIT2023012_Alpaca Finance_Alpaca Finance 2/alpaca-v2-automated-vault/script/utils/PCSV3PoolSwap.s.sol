// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";
import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";

contract PCSV3PoolSwapScript is BaseScript {

  function run() public {
    address _tokenIn = usdt;
    address _tokenOut = wbnb;
    uint24 _fee = 500;
    uint256 _amountIn = 10000;

    IPancakeV3Router.ExactInputParams memory params = IPancakeV3Router.ExactInputParams({
      path: abi.encodePacked(_tokenIn, _fee, _tokenOut),
      recipient: vm.addr(deployerPrivateKey),
      amountIn: _amountIn,
      amountOutMinimum: 0
    });
    vm.startBroadcast(deployerPrivateKey);

    ERC20(_tokenIn).approve(pancakeV3Router, _amountIn);
    IPancakeV3Router(pancakeV3Router).exactInput(params);

    vm.stopBroadcast();
  }
}
