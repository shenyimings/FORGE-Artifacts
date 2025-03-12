// SPDX-License-Identifier: GPL-2.0

pragma solidity 0.7.6;

import '../../interfaces/IAaveAddressHolder.sol';
import '../../interfaces/IRegistry.sol';

contract AaveAddressHolder is IAaveAddressHolder {
    address public override lendingPoolAddress;
    IRegistry public registry;

    constructor(address _lendingPoolAddress, address _registry) {
        lendingPoolAddress = _lendingPoolAddress;
        registry = IRegistry(_registry);
    }

    ///@notice Set the address of the lending pool from aave
    ///@param newAddress The address of the lending pool from aave
    function setLendingPoolAddress(address newAddress) external override onlyGovernance {
        lendingPoolAddress = newAddress;
    }

    ///@notice Set the address of the registry
    ///@param newAddress The address of the registry
    function setRegistry(address newAddress) external override onlyGovernance {
        registry = IRegistry(newAddress);
    }

    ///@notice restrict some function called only by governance
    modifier onlyGovernance() {
        require(
            msg.sender == registry.governance(),
            'AaveAddressHolder::onlyGovernance: Only governance can call this function'
        );
        _;
    }
}
