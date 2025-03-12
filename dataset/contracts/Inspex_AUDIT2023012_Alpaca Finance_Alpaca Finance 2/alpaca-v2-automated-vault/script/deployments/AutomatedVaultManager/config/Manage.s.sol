// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";

contract ManageScript is BaseScript {
  function run() public {
    address _vaultToken = 0x5dc672d3528535a97173AeD4671ccd2E5f627e44;
    address _worker = 0x4a0cb84D2DD2bc0Aa5CC256EF6Ec3A4e1b83E74c;
    // tick rage +- 20% from 240.887 USDT per BNB
    int24 _tickLower = -57080;
    int24 _tickUpper = -52610;

    uint256 _usdtWorkerBalance = ERC20(usdt).balanceOf(_worker);
    uint256 _wbnbWorkerBalance = ERC20(wbnb).balanceOf(_worker);

    uint256 _usdtToBorrow = 1 ether;
    uint256 _wbnbToBorrow = 0.004166666667 ether;

    // maange input
    bytes[] memory executorData = new bytes[](5);
    executorData[0] = _getBorrowTokenBytes(usdt, _usdtToBorrow);
    executorData[1] = _getBorrowTokenBytes(wbnb, _wbnbToBorrow);
    executorData[2] = _getOpenPositionBytes(
      _tickLower, _tickUpper, (_usdtToBorrow + _usdtWorkerBalance), (_wbnbToBorrow + _wbnbWorkerBalance)
    );

    vm.startBroadcast(deployerPrivateKey);

    AutomatedVaultManager(automatedVaultManager).manage(_vaultToken, executorData);

    vm.stopBroadcast();
  }

  function _getOpenPositionBytes(int24 _tickLower, int24 _tickUpper, uint256 _amount0, uint256 _amount1)
    internal
    pure
    returns (bytes memory _data)
  {
    _data = abi.encodeCall(PCSV3Executor01.openPosition, (_tickLower, _tickUpper, _amount0, _amount1));
  }

  function _getBorrowTokenBytes(address _token, uint256 _amount) internal pure returns (bytes memory _data) {
    _data = abi.encodeCall(PCSV3Executor01.borrow, (_token, _amount));
  }

  function _getClosePositionBytes() internal pure returns (bytes memory _data) {
    _data = abi.encodeCall(PCSV3Executor01.closePosition, ());
  }
}
