// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../metatx/interfaces/IForwarderRegistry.sol";
import {AccessControlStorage} from "./../access/libraries/AccessControlStorage.sol";
import {SealsStorage} from "./libraries/SealsStorage.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {SealsBase} from "./base/SealsBase.sol";
import {ContractOwnership} from "./../access/ContractOwnership.sol";
import {AccessControl} from "./../access/AccessControl.sol";
import {ForwarderRegistryContextBase} from "./../metatx/base/ForwarderRegistryContextBase.sol";

/// @title Sealead executions via calls on target contracts.
/// @notice Enables contract calls to be performed uniquely thanks to a seal identifier.
/// @notice Multiple executions can happen for example due to automation bugs in a backend or in a script.
/// @notice Typically, it can be a good practice to protect the minting of fungible tokens with an immutable seal identifier,
/// @notice such as a constant defined in a script or in a unique database field.
contract SealedExecutor is SealsBase, AccessControl, ForwarderRegistryContextBase {
    using SealsStorage for SealsStorage.Layout;
    using AccessControlStorage for AccessControlStorage.Layout;
    using Address for address;

    bytes32 public constant SEALER_ROLE = "sealer";

    constructor(IForwarderRegistry forwarderRegistry) ForwarderRegistryContextBase(forwarderRegistry) ContractOwnership(msg.sender) {}

    /// @notice Calls a contract function uniquely for a given seal identifier.
    /// @dev Reverts with {NotRoleHolder} if the sender does not have the sealer role.
    /// @dev Reverts with {AlreadySealed} if the sealId has already been used.
    /// @dev Emits a {Sealed} event.
    /// @param target The target contract.
    /// @param callData The encoded function call.
    /// @param sealId The seal identifier.
    /// @param returnData The data returned by the call.
    function sealedCall(address target, bytes calldata callData, uint256 sealId) external returns (bytes memory returnData) {
        address sealer = _msgSender();
        AccessControlStorage.layout().enforceHasRole(SEALER_ROLE, sealer);
        SealsStorage.layout().seal(sealer, sealId);
        return target.functionCall(callData);
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
