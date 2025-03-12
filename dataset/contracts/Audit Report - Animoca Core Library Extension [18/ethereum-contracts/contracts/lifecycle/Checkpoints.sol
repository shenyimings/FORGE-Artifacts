// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {CheckpointsBase} from "./base/CheckpointsBase.sol";
import {ContractOwnership} from "./../access/ContractOwnership.sol";

/// @title Timestamp-based checkpoints management (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract Checkpoints is CheckpointsBase, ContractOwnership {

}
