// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {ITokenMetadataResolver} from "./../../metadata/interfaces/ITokenMetadataResolver.sol";
import {ProxyAdminStorage} from "./../../../proxy/libraries/ProxyAdminStorage.sol";
import {TokenMetadataStorage} from "./../../metadata/libraries/TokenMetadataStorage.sol";
import {ERC1155Storage} from "./../libraries/ERC1155Storage.sol";
import {ERC1155MetadataBase} from "./../base/ERC1155MetadataBase.sol";
import {ForwarderRegistryContextBase} from "./../../../metatx/base/ForwarderRegistryContextBase.sol";

/// @title ERC1155 Multi Token Standard, optional extension: Metadata (facet version).
/// @notice This contracts uses an external resolver for managing individual tokens metadata.
/// @dev This contract is to be used as a diamond facet (see ERC2535 Diamond Standard https://eips.ethereum.org/EIPS/eip-2535).
/// @dev Note: This facet depends on {ProxyAdminFacet} and {InterfaceDetectionFacet}.
contract ERC1155MetadataFacet is ERC1155MetadataBase, ForwarderRegistryContextBase {
    using ProxyAdminStorage for ProxyAdminStorage.Layout;
    using TokenMetadataStorage for TokenMetadataStorage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) ForwarderRegistryContextBase(forwarderRegistry) {}

    /// @notice Initializes the storage with the contract metadata.
    /// @notice Sets the proxy initialization phase to `1`.
    /// @notice Marks the following ERC165 interfaces as supported: ERC1155MetadataURI.
    /// @dev Reverts with {NotProxyAdmin} if the sender is not the proxy admin.
    /// @dev Reverts with {InitializationPhaseAlreadyReached} if the proxy initialization phase is set to `1` or above.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    /// @param metadataResolver The address of the metadata resolver contract.
    function initERC1155MetadataStorage(string calldata name, string calldata symbol, ITokenMetadataResolver metadataResolver) external {
        ProxyAdminStorage.layout().enforceIsProxyAdmin(_msgSender());
        TokenMetadataStorage.layout().proxyInit(name, symbol, metadataResolver);
        ERC1155Storage.initERC1155MetadataURI();
    }
}
