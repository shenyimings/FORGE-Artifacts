// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IZNSRegistry } from "./IZNSRegistry.sol";
import { AAccessControlled } from "../access/AAccessControlled.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/**
 * @title The main reference data contract in ZNS. Also, often, the last contract
 * in the call chain of many operations where the most crucial Name owner data settles.
 * Owner of a domain in this contract also serves as the owner of the stake in `ZNSTreasury`.
 */
contract ZNSRegistry is AAccessControlled, UUPSUpgradeable, IZNSRegistry {

    // Mapping of all approved resolvers
    mapping(string resolverType => address resolver) internal resolvers;

    /**
     * @notice Mapping of `domainHash` to [DomainRecord](./IZNSRegistry.md#iznsregistry) struct to hold information
     * about each domain
     */
    mapping(bytes32 domainHash => DomainRecord domainRecord) internal records;

    /**
     * @notice Mapping of `owner` => `operator` => `bool` to show accounts that
     * are or aren't allowed access to domains that `owner` has access to.
     * Note that operators can NOT change the owner of the domain, but can change
     * the resolver or resolver records.
     */
    mapping(address owner => mapping(address operator => bool isOperator))
        internal operators;

    /**
     * @notice Revert if `msg.sender` is not the owner or an operator allowed by the owner
     * @param domainHash the hash of a domain's name
     */
    modifier onlyOwnerOrOperator(bytes32 domainHash) {
        require(
            isOwnerOrOperator(domainHash, msg.sender),
            "ZNSRegistry: Not authorized"
        );
        _;
    }

    /**
     * @notice Revert if `msg.sender` is not the owner. Used for owner restricted functions.
     * @param domainHash the hash of a domain's name
     */
    modifier onlyOwner(bytes32 domainHash) {
        require(
            records[domainHash].owner == msg.sender,
            "ZNSRegistry: Not the Name Owner"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializer for the `ZNSRegistry` proxy.
     * @param accessController_ The address of the `ZNSAccessController` contract
     * @dev ! The owner of the 0x0 hash should be a multisig ideally, but EOA can be used to deploy !
     * > Admin account deploying the contract will be the owner of the 0x0 hash !
     */
    function initialize(address accessController_) external override initializer {
        records[0x0].owner = msg.sender;
        _setAccessController(accessController_);
    }

    /**
     * @notice Checks if a given domain exists
     * @param domainHash The hash of a domain's name
     */
    function exists(bytes32 domainHash) external view override returns (bool) {
        return _exists(domainHash);
    }

    /**
     * @notice Checks if provided address is an owner or an operator of the provided domain
     * @param domainHash The hash of a domain's name
     * @param candidate The address for which we are checking access
     */
    function isOwnerOrOperator(
        bytes32 domainHash,
        address candidate
    ) public view override returns (bool) {
        address owner = records[domainHash].owner;
        return candidate == owner || operators[owner][candidate];
    }

    /**
     * @notice External function that checks if provided address is an operator for the provided owner.
     * @param operator The address for which we are checking access
     * @param owner The owner of the domain(-s) in question
    */
    function isOperatorFor(
        address operator,
        address owner
    ) external view override returns (bool) {
        return operators[owner][operator];
    }

    /**
     * @notice Set an `operator` as `allowed` to give or remove permissions for ALL
     * domains owned by the owner `msg.sender`.
     * Emits an `OperatorPermissionSet` event.
     * @param operator The account to allow/disallow
     * @param allowed The true/false value to set
     */
    function setOwnersOperator(address operator, bool allowed) external override {
        operators[msg.sender][operator] = allowed;

        emit OperatorPermissionSet(msg.sender, operator, allowed);
    }

    /**
     * @notice Gets a record for a domain (owner, resolver) from the internal mapping
     * `records`. `records` maps a domain hash to a
     * [DomainRecord](./IZNSRegistry.md#iznsregistry) struct.
     * @param domainHash the hash of a domain's name
     */
    function getDomainRecord(
        bytes32 domainHash
    ) external view override returns (DomainRecord memory) {
        return records[domainHash];
    }

    /**
     * @notice Gets the owner of the given domain
     * @param domainHash the hash of a domain's name
     */
    function getDomainOwner(
        bytes32 domainHash
    ) external view override returns (address) {
        return records[domainHash].owner;
    }

    /**
     * @notice Gets the resolver set for the given domain.
     * @param domainHash the hash of a domain's name
     */
    function getDomainResolver(
        bytes32 domainHash
    ) external view override returns (address) {
        return records[domainHash].resolver;
    }

    /**
     * @notice Creates a new domain record. Only callable by the `ZNSRootRegistrar.sol`
     * or an address that has REGISTRAR_ROLE. This is one of the last calls in the Register
     * flow that starts from `ZNSRootRegistrar.registerRootDomain()`. Calls 2 internal functions to set
     * the owner and resolver of the domain separately.
     * Can be called with `resolver` param as 0, which will exclude the call to set resolver.
     * Emits `DomainOwnerSet` and possibly `DomainResolverSet` events.
     * @param domainHash The hash of the domain name
     * @param owner The owner of the new domain
     * @param resolverType The string identifier of the resolver for the new domain, e.g. "address"
     */
    function createDomainRecord(
        bytes32 domainHash,
        address owner,
        string calldata resolverType
    ) external override onlyRegistrar {
        _setDomainOwner(domainHash, owner);

        // We allow creation of partial domain data with no resolver address
        if (bytes(resolverType).length != 0) {
            _setDomainResolver(domainHash, resolverType);
        }
    }

    /**
     * @notice Given a resolver type, returns the address of the resolver contract for that type or 0x0 if not found
     * @param resolverType The resolver type as a string, e.g. "address"
     */
    function getResolverType(string calldata resolverType) public view override returns(address) {
        return resolvers[resolverType];
    }

    /**
     * @notice Add a new resolver type option to the mapping of types
     * This function can also be used to update the resolver mapping for an existing resolver 
     * simple by using an existing key like "address" with a new address
     * @param resolverType The type of the resolver to add
     * @param resolver The address of the new resolver contract
     */
    function addResolverType(string calldata resolverType, address resolver) public override onlyAdmin {
        resolvers[resolverType] = resolver;
        emit ResolverAdded(resolverType, resolver);
    }

    /**
     * @notice Delete a resolver type from the mapping of types
     * @param resolverType The type to be removed
     */
    function deleteResolverType(string calldata resolverType) public override onlyAdmin {
        delete resolvers[resolverType];
        emit ResolverDeleted(resolverType);
    }

    /**
     * @notice Updates an existing domain record's owner and resolver.
     * Note that this function can ONLY be called by the Name owner of the domain.
     * This is NOT used by the `ZNSRootRegistrar.sol` contract and serves as a user facing function
     * for the owners of existing domains to change their data on this contract. A domain
     * `operator` can NOT call this, since he is not allowed to change the owner.
     * Emits `DomainOwnerSet` and `DomainResolverSet` events.
     * @param domainHash The hash of the domain
     * @param owner The owner or an allowed operator of that domain
     * @param resolverType The resolver for the domain
     */
    function updateDomainRecord(
        bytes32 domainHash,
        address owner,
        string calldata resolverType
    ) external override onlyOwner(domainHash) {
        // `exists` is checked implicitly through the modifier
        _setDomainOwner(domainHash, owner);
        _setDomainResolver(domainHash, resolverType);
    }

    /**
     * @notice Updates the owner of an existing domain. Can be called by either the Name owner
     * on this contract OR the `ZNSRootRegistrar.sol` contract as part of the Reclaim flow
     * that starts at `ZNSRootRegistrar.sol.reclaim()`. Emits an `DomainOwnerSet` event.
     * @param domainHash the hash of a domain's name
     * @param owner The account to transfer ownership to
     */
    function updateDomainOwner(
        bytes32 domainHash,
        address owner
    ) external override {
        require(
            msg.sender == records[domainHash].owner ||
            accessController.isRegistrar(msg.sender),
            "ZNSRegistry: Only Name Owner or Registrar allowed to call"
        );

        _setDomainOwner(domainHash, owner);
    }

    /**
     * @notice Updates the resolver of an existing domain in `records`.
     * Can be called by either the owner of the Name or an allowed operator.
     * @param domainHash the hash of a domain's name
     * @param resolverType The new Resolver contract address
     */
    function updateDomainResolver(
        bytes32 domainHash,
        string calldata resolverType
    ) external override onlyOwnerOrOperator(domainHash) {
        // `exists` is checked implicitly through the modifier
        _setDomainResolver(domainHash, resolverType);
    }

    /**
     * @notice Deletes a domain's record from this contract's state.
     * This can ONLY be called by the `ZNSRootRegistrar.sol` contract as part of the Revoke flow
     * or any address holding the `REGISTRAR_ROLE`. Emits a `DomainRecordDeleted` event.
     * @param domainHash The hash of the domain name
     */
    function deleteRecord(bytes32 domainHash) external override onlyRegistrar {
        delete records[domainHash];

        emit DomainRecordDeleted(domainHash);
    }

    /**
     * @notice Check if a domain exists. True if the owner is not `0x0`
     * @param domainHash the hash of a domain's name
     */
    function _exists(bytes32 domainHash) internal view returns (bool) {
        return records[domainHash].owner != address(0);
    }

    /**
     * @notice Internal function to set a domain's owner in state `records`.
     * Owner can NOT be set to 0, since we use delete operation as part of the
     * ``deleteRecord()`` function.
     * Emits a `DomainOwnerSet` event.
     * @param domainHash the hash of a domain's name
     * @param owner The owner to set
     */
    function _setDomainOwner(bytes32 domainHash, address owner) internal {
        require(owner != address(0), "ZNSRegistry: Owner cannot be zero address");
        records[domainHash].owner = owner;
        emit DomainOwnerSet(domainHash, owner);
    }

    /**
     * @notice Internal function to set a domain's resolver in state `records`.
     * Resolver can be set to 0, since we allow partial domain data. Emits a `DomainResolverSet` event.
     * @param domainHash the hash of a domain's name
     * @param resolverType The resolver to set
     */
    function _setDomainResolver(
        bytes32 domainHash,
        string calldata resolverType
    ) internal {
        address resolver = resolvers[resolverType];

        records[domainHash].resolver = resolver;
        emit DomainResolverSet(domainHash, resolver);
    }

    /**
     * @notice To use UUPS proxy we override this function and revert if `msg.sender` isn't authorized
     * @param newImplementation The implementation contract to upgrade to
     */
    // solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal view override {
        accessController.checkGovernor(msg.sender);
    }
}
