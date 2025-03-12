// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '../core/FoldingRegistry.sol';

contract FoldingRegistryUpgradedMock is FoldingRegistry {
    uint256 public newStorageVariable;

    function version() external pure virtual override returns (uint8) {
        return 2;
    }

    function newViewFunction() external pure virtual returns (bool) {
        return true;
    }

    function setNewStorageVariable(uint256 newValue) external {
        newStorageVariable = newValue;
    }
}
