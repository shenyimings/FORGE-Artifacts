// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IPause} from "./../interfaces/IPause.sol";
import {PauseStorage} from "./../libraries/PauseStorage.sol";
import {ContractOwnershipStorage} from "./../../access/libraries/ContractOwnershipStorage.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/// @title Pausing mechanism (proxiable version).
/// @dev This contract is to be used via inheritance in a proxied implementation.
/// @dev Note: This contract requires ERC173 (Contract Ownership standard).
abstract contract PauseBase is IPause, Context {
    using PauseStorage for PauseStorage.Layout;
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    /// @notice Pauses the contract.
    /// @dev Reverts with {NotContractOwner} if the sender is not the contract owner.
    /// @dev Reverts with {Paused} if the contract is paused.
    /// @dev Emits a {Paused} event.
    function pause() external {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        PauseStorage.layout().pause();
    }

    /// @notice Unpauses the contract.
    /// @dev Reverts with {NotContractOwner} if the sender is not the contract owner.
    /// @dev Reverts with {NotPaused} if the contract is not paused.
    /// @dev Emits an {Unpaused} event.
    function unpause() external {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        PauseStorage.layout().unpause();
    }

    // /// @inheritdoc IPause
    function paused() external view returns (bool) {
        return PauseStorage.layout().paused();
    }
}
