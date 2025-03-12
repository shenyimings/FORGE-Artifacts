// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IDistributionConfig } from "../types/IDistributionConfig.sol";
import { PaymentConfig } from "../treasury/IZNSTreasury.sol";


/**
 * @notice Stake fee is 0x0 for anything other than subdomain under a parent with Stake Payment
 * parent hash will be 0x0 for root domain
 */
struct CoreRegisterArgs {
    bytes32 parentHash;
    bytes32 domainHash;
    address registrant;
    address domainAddress;
    uint256 price;
    uint256 stakeFee;
    string label;
    string tokenURI;
    bool isStakePayment;
    PaymentConfig paymentConfig;
}

/**
 * @title IZNSRootRegistrar.sol - Interface for the ZNSRootRegistrar contract resposible for registering root domains.
 * @notice Below are docs for the types in this file:
 *  - `OwnerOf`: Enum signifying ownership of ZNS entities
 *      + NAME: The owner of the Name only
 *      + TOKEN: The owner of the Token only
 *      + BOTH: The owner of both the Name and the Token
 *  - `CoreRegisterArgs`: Struct containing all the arguments required to register a domain
 *  with ZNSRootRegistrar.coreRegister():
 *      + `parentHash`: The hash of the parent domain (0x0 for root domains)
 *      + `domainHash`: The hash of the domain to be registered
 *      + `label`: The label of the domain to be registered
 *      + `registrant`: The address of the user who is registering the domain
 *      + `price`: The determined price for the domain to be registered based on parent rules
 *      + `stakeFee`: The determined stake fee for the domain to be registered (only for PaymentType.STAKE!)
 *      + `domainAddress`: The address to which the domain will be resolved to
 *      + `tokenURI`: The tokenURI for the domain to be registered
 *      + `isStakePayment`: A flag for whether the payment is a stake payment or not
 */
interface IZNSRootRegistrar is IDistributionConfig {

    enum OwnerOf {
        NAME,
        TOKEN,
        BOTH
    }

    /**
     * @notice Emitted when a NEW domain is registered.
     * @dev `domainAddress` parameter is the address to which a domain name will relate to in ZNS.
     * E.g. if a user made a domain for his wallet, the address of the wallet will be the `domainAddress`.
     * This can be 0 as this variable is not required to perform registration process
     * and can be set at a later time by the domain owner.
     * @param parentHash The hash of the parent domain (0x0 for root domains)
     * @param label The name as the last part of the full domain string (level) registered
     * @param domainHash The hash of the domain registered
     * @param tokenId The tokenId of the domain registered
     * @param tokenURI The tokenURI of the domain registered
     * @param registrant The address that called `ZNSRootRegistrar.registerRootDomain()`
     * @param domainAddress The domain address of the domain registered
     */
    event DomainRegistered(
        bytes32 parentHash,
        bytes32 indexed domainHash,
        string label,
        uint256 indexed tokenId,
        string tokenURI,
        address indexed registrant,
        address domainAddress
    );

    /**
     * @notice Emitted when a domain is revoked.
     * @param domainHash The hash of the domain revoked
     * @param owner The address that called `ZNSRootRegistrar.sol.revokeDomain()` and domain owner
     * @param stakeRefunded A flag for whether the stake was refunded or not
     */
    event DomainRevoked(
        bytes32 indexed domainHash,
        address indexed owner,
        bool indexed stakeRefunded
    );

    /**
     * @notice Emitted when an ownership of the Name is reclaimed by the Token owner.
     * @param domainHash The hash of the domain reclaimed
     * @param registrant The address that called `ZNSRootRegistrar.sol.reclaimDomain()`
     */
    event DomainReclaimed(
        bytes32 indexed domainHash,
        address indexed registrant
    );

    /**
     * @notice Emitted when the `rootPricer` address is set in state.
     * @param rootPricer The new address of any IZNSPricer type contract
     */
    event RootPricerSet(address rootPricer);

    /**
     * @notice Emitted when the `treasury` address is set in state.
     * @param treasury The new address of the Treasury contract
     */
    event TreasurySet(address treasury);

    /**
     * @notice Emitted when the `domainToken` address is set in state.
     * @param domainToken The new address of the DomainToken contract
     */
    event DomainTokenSet(address domainToken);

    /**
     * @notice Emitted when the `subRegistrar` address is set in state.
     * @param subRegistrar The new address of the SubRegistrar contract
     */
    event SubRegistrarSet(address subRegistrar);

    function initialize(
        address accessController_,
        address registry_,
        address rootPricer_,
        address treasury_,
        address domainToken_
    ) external;

    function registerRootDomain(
        string calldata name,
        address domainAddress,
        string calldata tokenURI,
        DistributionConfig calldata distributionConfig,
        PaymentConfig calldata paymentConfig
    ) external returns (bytes32);

    function coreRegister(
        CoreRegisterArgs memory args
    ) external;

    function revokeDomain(bytes32 domainHash) external;

    function reclaimDomain(bytes32 domainHash) external;

    function isOwnerOf(bytes32 domainHash, address candidate, OwnerOf ownerOf) external view returns (bool);

    function setRegistry(address registry_) external;

    function setRootPricer(address rootPricer_) external;

    function setTreasury(address treasury_) external;

    function setDomainToken(address domainToken_) external;

    function setSubRegistrar(address subRegistrar_) external;
}
