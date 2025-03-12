// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../metatx/interfaces/IForwarderRegistry.sol";
import {ContractOwnershipStorage} from "./../../access/libraries/ContractOwnershipStorage.sol";
import {ContractOwnership} from "./../../access/ContractOwnership.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../metatx/ForwarderRegistryContext.sol";

contract ContractOwnershipMock is ContractOwnership, ForwarderRegistryContext {
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    constructor(
        address initialOwner,
        IForwarderRegistry forwarderRegistry
    ) ContractOwnership(initialOwner) ForwarderRegistryContext(forwarderRegistry) {}

    function enforceIsContractOwner(address account) external view {
        ContractOwnershipStorage.layout().enforceIsContractOwner(account);
    }

    function enforceIsTargetContractOwner(address targetContract, address account) external view {
        ContractOwnershipStorage.enforceIsTargetContractOwner(targetContract, account);
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
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
