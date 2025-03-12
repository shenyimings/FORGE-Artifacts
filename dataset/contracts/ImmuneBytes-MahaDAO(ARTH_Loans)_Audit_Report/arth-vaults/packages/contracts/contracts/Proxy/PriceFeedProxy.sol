// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import {UpgradableProxy} from "./UpgradableProxy.sol";

contract PriceFeedProxy is UpgradableProxy {
    constructor(address _proxyTo) public UpgradableProxy(_proxyTo) {}
}
