// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IOperatorFilterRegistry} from "./../royalty/interfaces/IOperatorFilterRegistry.sol";
import {ERC1155Storage} from "./libraries/ERC1155Storage.sol";
import {OperatorFiltererStorage} from "./../royalty/libraries/OperatorFiltererStorage.sol";
import {ERC1155WithOperatorFiltererBase} from "./base/ERC1155WithOperatorFiltererBase.sol";
import {OperatorFiltererBase} from "./../royalty/base/OperatorFiltererBase.sol";
import {ContractOwnership} from "./../../access/ContractOwnership.sol";

/// @title ERC1155 Multi Token Standard with Operator Filterer (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC1155WithOperatorFilterer is ERC1155WithOperatorFiltererBase, OperatorFiltererBase, ContractOwnership {
    using OperatorFiltererStorage for OperatorFiltererStorage.Layout;

    /// @notice Marks the following ERC165 interfaces as supported: ERC1155.
    /// @notice Sets the address that the contract will make OperatorFilter checks against.
    /// @param operatorFilterRegistry The operator filter registry address. When set to the zero address, checks will be bypassed.
    constructor(IOperatorFilterRegistry operatorFilterRegistry) {
        ERC1155Storage.init();
        OperatorFiltererStorage.layout().constructorInit(operatorFilterRegistry);
    }
}
