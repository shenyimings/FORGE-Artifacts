// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPoolConfigurator} from "@aave-v3-core/interfaces/IPoolConfigurator.sol";

contract PoolAdminMock {
    IPoolConfigurator internal immutable _POOL_CONFIGURATOR;

    constructor(IPoolConfigurator poolConfigurator) {
        _POOL_CONFIGURATOR = poolConfigurator;
    }

    function setSupplyCap(address underlying, uint256 supplyCap) external {
        _POOL_CONFIGURATOR.setSupplyCap(underlying, supplyCap);
    }

    function setBorrowCap(address underlying, uint256 borrowCap) external {
        _POOL_CONFIGURATOR.setBorrowCap(underlying, borrowCap);
    }
}
