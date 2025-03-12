// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IOperatorFilterRegistry} from "./../interfaces/IOperatorFilterRegistry.sol";
import {OperatorFiltererStorage} from "./../libraries/OperatorFiltererStorage.sol";
import {ContractOwnershipStorage} from "./../../../access/libraries/ContractOwnershipStorage.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/// @title Operator Filterer for token contracts (proxiable version).
/// @dev This contract is to be used via inheritance in a proxied implementation.
/// @dev Note: This contract requires ERC173 (Contract Ownership standard).
abstract contract OperatorFiltererBase is Context {
    using OperatorFiltererStorage for OperatorFiltererStorage.Layout;
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    /// @notice Updates the address that the contract will make OperatorFilter checks against.
    /// @dev Reverts with {NotContractOwner} if the sender is not the contract owner.
    /// @param registry The new operator filter registry address. When set to the zero address, checks will be bypassed.
    function updateOperatorFilterRegistry(IOperatorFilterRegistry registry) external {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        OperatorFiltererStorage.layout().updateOperatorFilterRegistry(registry);
    }

    /// @notice Gets the operator filter registry address.
    function operatorFilterRegistry() external view returns (IOperatorFilterRegistry) {
        return OperatorFiltererStorage.layout().operatorFilterRegistry();
    }
}
