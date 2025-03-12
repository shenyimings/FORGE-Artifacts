// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { AdminUpgradeabilityProxy } from "./AdminUpgradeabilityProxy.sol";

contract SimpleProxy is AdminUpgradeabilityProxy {
  constructor(address impl) public AdminUpgradeabilityProxy(impl) {}
}
