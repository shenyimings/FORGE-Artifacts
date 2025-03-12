// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {IOperatorFilterRegistry} from "./../interfaces/IOperatorFilterRegistry.sol";
import {OperatorFiltererStorage} from "./../libraries/OperatorFiltererStorage.sol";
import {ProxyAdminStorage} from "./../../../proxy/libraries/ProxyAdminStorage.sol";
import {OperatorFiltererBase} from "./../base/OperatorFiltererBase.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../../metatx/base/ForwarderRegistryContextBase.sol";

/// @title Operator Filterer for token contracts (facet version).
/// @dev This contract is to be used as a diamond facet (see ERC2535 Diamond Standard https://eips.ethereum.org/EIPS/eip-2535).
/// @dev Note: This facet depends on {ProxyAdminFacet} and {ContractOwnershipFacet}.
contract OperatorFiltererFacet is OperatorFiltererBase, ForwarderRegistryContextBase {
    using ProxyAdminStorage for ProxyAdminStorage.Layout;
    using OperatorFiltererStorage for OperatorFiltererStorage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) ForwarderRegistryContextBase(forwarderRegistry) {}

    /// @notice Sets the address that the contract will make OperatorFilter checks against.
    /// @dev Reverts with {NotProxyAdmin} if the sender is not the proxy admin.
    /// @dev Reverts with {InitializationPhaseAlreadyReached} if the proxy initialization phase is set to `1` or above.
    /// @param operatorFilterRegistry The operator filter registry address. When set to the zero address, checks will be bypassed.
    function initOperatorFilterer(IOperatorFilterRegistry operatorFilterRegistry) external {
        ProxyAdminStorage.layout().enforceIsProxyAdmin(_msgSender());
        OperatorFiltererStorage.layout().proxyInit(operatorFilterRegistry);
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
