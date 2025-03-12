// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IZNSAddressResolver } from "./IZNSAddressResolver.sol";
import { AAccessControlled } from "../access/AAccessControlled.sol";
import { ARegistryWired } from "../registry/ARegistryWired.sol";


/**
 * @title The specific Resolver for ZNS that maps domain hashes to Ethereum addresses these domains were made for.
 * @notice This Resolver supports ONLY the address type. Every domain in ZNS made for a contract or wallet address
 * will have a corresponding record in this Resolver.
 */
contract ZNSAddressResolver is
    UUPSUpgradeable,
    AAccessControlled,
    ARegistryWired,
    ERC165,
    IZNSAddressResolver {
    /**
     * @notice Mapping of domain hash to address used to bind domains
     * to Ethereum wallets or contracts registered in ZNS.
     */
    mapping(bytes32 domainHash => address resolvedAddress)
        internal domainAddresses;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializer for the `ZNSAddressResolver` proxy.
     * Note that setter functions are used instead of direct state variable assignments
     * to use access control at deploy time. Only ADMIN can call this function.
     * @param accessController_ The address of the `ZNSAccessController` contract
     * @param registry_ The address of the `ZNSRegistry` contract
     */
    function initialize(address accessController_, address registry_) external override initializer {
        _setAccessController(accessController_);
        setRegistry(registry_);
    }

    /**
     * @dev Returns address associated with a given domain name hash.
     * @param domainHash The identifying hash of a domain's name
     */
    function resolveDomainAddress(
        bytes32 domainHash
    ) external view override returns (address) {
        return domainAddresses[domainHash];
    }

    /**
     * @dev Sets the address for a domain name hash. This function can only
     * be called by the owner, operator of the domain OR by the `ZNSRootRegistrar.sol`
     * as a part of the Register flow.
     * Emits an `AddressSet` event.
     * @param domainHash The identifying hash of a domain's name
     * @param newAddress The new address to map the domain to
     */
    function setAddress(
        bytes32 domainHash,
        address newAddress
    ) external override {
        // only owner or operator of the current domain can set the address
        // also, ZNSRootRegistrar.sol can set the address as part of the registration process
        require(
            registry.isOwnerOrOperator(domainHash, msg.sender) ||
            accessController.isRegistrar(msg.sender),
            "ZNSAddressResolver: Not authorized for this domain"
        );

        domainAddresses[domainHash] = newAddress;

        emit AddressSet(domainHash, newAddress);
    }

    /**
     * @dev ERC-165 check for implementation identifier
     * @dev Supports interfaces IZNSAddressResolver and IERC165
     * @param interfaceId ID to check, XOR of the first 4 bytes of each function signature
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IZNSAddressResolver) returns (bool) {
        return
            interfaceId == getInterfaceId() ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Exposes IZNSAddressResolver interfaceId
     */
    function getInterfaceId() public pure override returns (bytes4) {
        return type(IZNSAddressResolver).interfaceId;
    }

    /**
     * @dev Sets the address of the `ZNSRegistry` contract that holds all crucial data
     * for every domain in the system. This function can only be called by the ADMIN.
     * Emits a `RegistrySet` event.
     * @param _registry The address of the `ZNSRegistry` contract
     */
    function setRegistry(address _registry) public override(ARegistryWired, IZNSAddressResolver) onlyAdmin {
        _setRegistry(_registry);
    }

    /**
     * @notice To use UUPS proxy we override this function and revert if `msg.sender` isn't authorized
     * @param newImplementation The implementation contract to upgrade to
     */
    // solhint-disable-next-line no-unused-vars
    function _authorizeUpgrade(address newImplementation) internal view override {
        accessController.checkGovernor(msg.sender);
    }
}
