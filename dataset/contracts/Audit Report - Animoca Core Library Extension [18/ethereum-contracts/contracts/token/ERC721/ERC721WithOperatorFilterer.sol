// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IOperatorFilterRegistry} from "./../royalty/interfaces/IOperatorFilterRegistry.sol";
import {ERC721Storage} from "./libraries/ERC721Storage.sol";
import {OperatorFiltererStorage} from "./../royalty/libraries/OperatorFiltererStorage.sol";
import {ERC721WithOperatorFiltererBase} from "./base/ERC721WithOperatorFiltererBase.sol";
import {OperatorFiltererBase} from "./../royalty/base/OperatorFiltererBase.sol";
import {ContractOwnership} from "./../../access/ContractOwnership.sol";

/// @title ERC721 Non-Fungible Token Standard with Operator Filterer (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC721WithOperatorFilterer is ERC721WithOperatorFiltererBase, OperatorFiltererBase, ContractOwnership {
    using OperatorFiltererStorage for OperatorFiltererStorage.Layout;

    /// @notice Marks the following ERC165 interfaces as supported: ERC721.
    /// @notice Sets the address that the contract will make OperatorFilter checks against.
    /// @param operatorFilterRegistry The operator filter registry address. When set to the zero address, checks will be bypassed.
    constructor(IOperatorFilterRegistry operatorFilterRegistry) {
        ERC721Storage.init();
        OperatorFiltererStorage.layout().constructorInit(operatorFilterRegistry);
    }
}
