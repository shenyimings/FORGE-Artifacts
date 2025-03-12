// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC2771} from "./../interfaces/IERC2771.sol";
import {IForwarderRegistry} from "./../interfaces/IForwarderRegistry.sol";

/// @title Meta-Transactions Forwarder Registry Context (facet version).
/// @dev This contract is to be used as a diamond facet (see ERC2535 Diamond Standard https://eips.ethereum.org/EIPS/eip-2535).
/// @dev Derived from https://github.com/wighawag/universal-forwarder (MIT licence)
contract ForwarderRegistryContextFacet is IERC2771 {
    IForwarderRegistry internal immutable _FORWARDER_REGISTRY;

    constructor(IForwarderRegistry forwarderRegistry_) {
        _FORWARDER_REGISTRY = forwarderRegistry_;
    }

    function forwarderRegistry() external view returns (IForwarderRegistry) {
        return _FORWARDER_REGISTRY;
    }

    /// @inheritdoc IERC2771
    function isTrustedForwarder(address forwarder) external view virtual returns (bool) {
        return forwarder == address(_FORWARDER_REGISTRY);
    }
}
