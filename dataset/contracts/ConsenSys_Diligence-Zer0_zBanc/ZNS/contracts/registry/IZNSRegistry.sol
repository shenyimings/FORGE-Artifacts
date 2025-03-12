// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


/**
 * @notice The `DomainRecord` struct is meant to hold relevant information
 * about a domain, such as its owner and resolver.
 * - `owner` (address): The owner of the domain (also called the owner of the Name).
 * - `resolver` (address): The address of the Resolver contract where this domain's source records are stored.
 *
 * In the future, there will be multiple Resolver contracts that support different types of sources.
 * Currently, only the `ZNSAddressResolver` is implemented.
 */
interface IZNSRegistry {

    /**
     * @notice Description of a domain record, pointing to the 
     * owner address of that record as well as the address of
     * its resolver
     */
    struct DomainRecord {
        address owner;
        address resolver;
    }

    /**
     * @notice Emits when ownership of a domain is modified in ``records``
     * @param domainHash the hash of a domain's name
     * @param owner The new domain owner
     */
    event DomainOwnerSet(
        bytes32 indexed domainHash,
        address indexed owner
    );

    /**
     * @notice Emit when a domain's resolver is modified in ``records``
     * @param domainHash the hash of a domain's name
     * @param resolver The new resolver address
     */
    event DomainResolverSet(
        bytes32 indexed domainHash,
        address indexed resolver
    );

    /**
     * @notice Emits when a domain record is deleted
     * @param domainHash The hash of a domain's name
     */
    event DomainRecordDeleted(
        bytes32 indexed domainHash
    );

    /**
     * @notice Emit when an owner allows/disallows permissions for an operator
     * @param owner Owner of the domain in question
     * @param operator Address that was allowed/disallowed
     * @param allowed Boolean status of their permission
     */
    event OperatorPermissionSet(
        address indexed owner,
        address indexed operator,
        bool allowed
    );

    /**
     * @notice Emitted when a new resolver type is added to ZNS
     * @param resolverType The name of the resolver type
     * @param resolver The address of the resolver contract
     */
    event ResolverAdded(
        string resolverType,
        address resolver
    );

    /**
     * @notice Emitted when a resolver is deleted from ZNS
     * @param resolverType The name of the resolver type
     */
    event ResolverDeleted(
        string resolverType
    );

    function initialize(address accessController) external;

    function exists(bytes32 domainHash) external view returns (bool);

    function isOwnerOrOperator(
        bytes32 domainHash,
        address candidate
    ) external view returns (bool);

    function isOperatorFor(
        address operator,
        address owner
    ) external view returns (bool);

    /**
     * @notice Set an `operator` as `allowed` to give or remove permissions for all
     * domains owned by `msg.sender`
     * @param operator The account to allow/disallow
     * @param allowed The true/false value to set
     */
    function setOwnersOperator(address operator, bool allowed) external;

    function getDomainRecord(
        bytes32 domainHash
    ) external view returns (DomainRecord memory);

    function getDomainOwner(
        bytes32 domainHash
    ) external view returns (address);

    function getDomainResolver(
        bytes32 domainHash
    ) external view returns (address);

    function createDomainRecord(
        bytes32 domainHash,
        address owner,
        string calldata resolverType
    ) external;

    function getResolverType(
        string calldata resolverType
    ) external returns (address); 

    function addResolverType(
        string calldata resolverType,
        address resolver
    ) external;

    function deleteResolverType(
        string calldata resolverType
    ) external;

    function updateDomainRecord(
        bytes32 domainHash,
        address owner,
        string calldata resolverType
    ) external;

    function updateDomainOwner(bytes32 domainHash, address owner) external;

    function updateDomainResolver(
        bytes32 domainHash,
        string calldata resolverType
    ) external;

    function deleteRecord(bytes32 domainHash) external;
}
