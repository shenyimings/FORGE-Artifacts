// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20Storage} from "./libraries/ERC20Storage.sol";
import {ERC20Base} from "./base/ERC20Base.sol";
import {InterfaceDetection} from "./../../introspection/InterfaceDetection.sol";

/// @title ERC20 Fungible Token Standard (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC20 is ERC20Base, InterfaceDetection {
    /// @notice Marks the following ERC165 interface(s) as supported: ERC20, ERC20Allowance.
    constructor() {
        ERC20Storage.init();
    }
}
