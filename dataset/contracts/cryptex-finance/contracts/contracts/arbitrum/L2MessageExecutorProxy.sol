// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";
import {AddressAliasHelper} from "./AddressAliasHelper.sol";

contract L2MessageExecutorProxy is TransparentUpgradeableProxy {
  constructor(
    address l2MessageExecutor,
    address l2AdminProxy,
    bytes memory callData
  ) TransparentUpgradeableProxy(l2MessageExecutor, l2AdminProxy, callData) {}
}
