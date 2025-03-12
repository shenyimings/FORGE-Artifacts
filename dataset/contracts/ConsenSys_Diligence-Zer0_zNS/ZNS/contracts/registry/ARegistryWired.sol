// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IZNSRegistry } from "./IZNSRegistry.sol";


/**
 * @title ARegistryWired.sol - Abstract contract, intdroducing ZNSRegistry to the storage
 * of children contracts. Inheriting this contract means that child is connected to ZNSRegistry
 * and is able to get AC and domain data from it or write to it.
*/
abstract contract ARegistryWired {

    /**
     * @notice Emitted when the ZNSRegistry address is set in state of the child contract.
    */
    event RegistrySet(address registry);

    /**
     * @notice ZNSRegistry address in the state of the child contract.
    */
    IZNSRegistry public registry;

    modifier onlyOwnerOrOperator(bytes32 domainHash) {
        require(
            registry.isOwnerOrOperator(domainHash, msg.sender),
            "ARegistryWired: Not authorized. Only Owner or Operator allowed"
        );
        _;
    }

    /**
     * @notice Internal function to set the ZNSRegistry address in the state of the child contract.
    */
    function _setRegistry(address registry_) internal {
        require(registry_ != address(0), "ARegistryWired: _registry can not be 0x0 address");
        registry = IZNSRegistry(registry_);
        emit RegistrySet(registry_);
    }

    /**
     * @notice Virtual function to make sure the setter is always implemented in children,
     * otherwise we will not be able to reset the ZNSRegistry address in children
     * @dev The reason this function is not implemented here is because it has to be
     * implemented with Access Control that only child contract is connected to.
     */
    function setRegistry(address registry_) external virtual;
}
