// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { AAccessControlled } from "../access/AAccessControlled.sol";
import { ARegistryWired } from "../registry/ARegistryWired.sol";
import { IZNSRootRegistrar, CoreRegisterArgs } from "./IZNSRootRegistrar.sol";
import { IZNSTreasury, PaymentConfig } from "../treasury/IZNSTreasury.sol";
import { IZNSDomainToken } from "../token/IZNSDomainToken.sol";
import { IZNSAddressResolver } from "../resolver/IZNSAddressResolver.sol";
import { IZNSSubRegistrar } from "../registrar/IZNSSubRegistrar.sol";
import { IZNSPricer } from "../types/IZNSPricer.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { StringUtils } from "../utils/StringUtils.sol";


/**
 * @title Main entry point for the three main flows of ZNS - Register Root Domain, Reclaim and Revoke any domain.
 * @notice This contract serves as the "umbrella" for many ZNS operations, it is given REGISTRAR_ROLE
 * to combine multiple calls/operations between different modules to achieve atomic state changes
 * and proper logic for the ZNS flows. You can see functions in other modules that are only allowed
 * to be called by this contract to ensure proper management of ZNS data in multiple places.
 * RRR - Register, Reclaim, Revoke start here and then call other modules to complete the flow.
 * ZNSRootRegistrar.sol stores most of the other contract addresses and can communicate with other modules,
 * but the relationship is one-sided, where other modules do not need to know about the ZNSRootRegistrar.sol,
 * they only check REGISTRAR_ROLE that can, in theory, be assigned to any other address.
 * @dev This contract is also called at the last stage of registering subdomains, since it has the common
 * logic required to be performed for any level domains.
 */
contract ZNSRootRegistrar is
    UUPSUpgradeable,
    AAccessControlled,
    ARegistryWired,
    IZNSRootRegistrar {
    using StringUtils for string;

    IZNSPricer public rootPricer;
    IZNSTreasury public treasury;
    IZNSDomainToken public domainToken;
    IZNSSubRegistrar public subRegistrar;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Create an instance of the ZNSRootRegistrar.sol
     * for registering, reclaiming and revoking ZNS domains
     * @dev Instead of direct assignments, we are calling the setter functions
     * to apply Access Control and ensure only the ADMIN can set the addresses.
     * @param accessController_ Address of the ZNSAccessController contract
     * @param registry_ Address of the ZNSRegistry contract
     * @param rootPricer_ Address of the IZNSPricer type contract that Zero chose to use for the root domains
     * @param treasury_ Address of the ZNSTreasury contract
     * @param domainToken_ Address of the ZNSDomainToken contract
     */
    function initialize(
        address accessController_,
        address registry_,
        address rootPricer_,
        address treasury_,
        address domainToken_
    ) external override initializer {
        _setAccessController(accessController_);
        setRegistry(registry_);
        setRootPricer(rootPricer_);
        setTreasury(treasury_);
        setDomainToken(domainToken_);
    }

    /**
     * @notice This function is the main entry point for the Register Root Domain flow.
     * Registers a new root domain such as `0://wilder`.
     * Gets domain hash as a keccak256 hash of the domain label string casted to bytes32,
     * checks existence of the domain in the registry and reverts if it exists.
     * Calls `ZNSTreasury` to do the staking part, gets `tokenId` for the new token to be minted
     * as domain hash casted to uint256, mints the token and sets the domain data in the `ZNSRegistry`
     * and, possibly, `ZNSAddressResolver`. Emits a `DomainRegistered` event.
     * @param name Name (label) of the domain to register
     * @param domainAddress (optional) Address for the `ZNSAddressResolver` to return when requested
     * @param tokenURI URI to assign to the Domain Token issued for the domain
     * @param distributionConfig (optional) Distribution config for the domain to set in the same tx
     *     > Please note that passing distribution config will add more gas to the tx and most importantly -
     *      - the distributionConfig HAS to be passed FULLY filled or all zeros. It is optional as a whole,
     *      but all the parameters inside are required.
     * @param paymentConfig (optional) Payment config for the domain to set on ZNSTreasury in the same tx
     *  > `paymentConfig` has to be fully filled or all zeros. It is optional as a whole,
     *  but all the parameters inside are required.
     */
    function registerRootDomain(
        string calldata name,
        address domainAddress,
        string calldata tokenURI,
        DistributionConfig calldata distributionConfig,
        PaymentConfig calldata paymentConfig
    ) external override returns (bytes32) {
        // Confirms string values are only [a-z0-9-]
        name.validate();

        // Create hash for given domain name
        bytes32 domainHash = keccak256(bytes(name));

        require(
            !registry.exists(domainHash),
            "ZNSRootRegistrar: Domain already exists"
        );

        // Get price for the domain
        uint256 domainPrice = rootPricer.getPrice(0x0, name, true);

        _coreRegister(
            CoreRegisterArgs(
                bytes32(0),
                domainHash,
                msg.sender,
                domainAddress,
                domainPrice,
                0,
                name,
                tokenURI,
                true,
                paymentConfig
            )
        );

        if (address(distributionConfig.pricerContract) != address(0)) {
            // this adds additional gas to the register tx if passed
            subRegistrar.setDistributionConfigForDomain(domainHash, distributionConfig);
        }

        return domainHash;
    }

    /**
     * @notice External function used by `ZNSSubRegistrar` for the final stage of registering subdomains.
     * @param args `CoreRegisterArgs`: Struct containing all the arguments required to register a domain
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
    function coreRegister(
        CoreRegisterArgs memory args
    ) external override onlyRegistrar {
        _coreRegister(
            args
        );
    }

    /**
     * @dev Internal function that is called by this contract to finalize the registration of a domain.
     * This function as also called by the external `coreRegister()` function as a part of
     * registration of subdomains.
     * This function kicks off payment processing logic, mints the token, sets the domain data in the `ZNSRegistry`
     * and fires a `DomainRegistered` event.
     * For params see external `coreRegister()` docs.
    */
    function _coreRegister(
        CoreRegisterArgs memory args
    ) internal {
        // payment part of the logic
        if (args.price > 0) {
            _processPayment(args);
        }

        // Get tokenId for the new token to be minted for the new domain
        uint256 tokenId = uint256(args.domainHash);
        // mint token
        domainToken.register(args.registrant, tokenId, args.tokenURI);

        // set data on Registry (for all) + Resolver (optional)
        // If no domain address is given, only the domain owner is set, otherwise
        // `ZNSAddressResolver` is called to assign an address to the newly registered domain.
        // If the `domainAddress` is not provided upon registration, a user can call `ZNSAddressResolver.setAddress`
        // to set the address themselves.
        if (args.domainAddress != address(0)) {
            registry.createDomainRecord(args.domainHash, args.registrant, "address");

            IZNSAddressResolver(registry.getDomainResolver(args.domainHash))
                .setAddress(args.domainHash, args.domainAddress);
        } else {
            // By passing an empty string we tell the registry to not add a resolver
            registry.createDomainRecord(args.domainHash, args.registrant, "");
        }

        // Because we check in the web app for the existance of both values in a payment config,
        // it's fine to just check for one here
        if (args.paymentConfig.beneficiary != address(0)) {
            treasury.setPaymentConfig(args.domainHash, args.paymentConfig);
        }

        emit DomainRegistered(
            args.parentHash,
            args.domainHash,
            args.label,
            tokenId,
            args.tokenURI,
            args.registrant,
            args.domainAddress
        );
    }

    /**
     * @dev Internal function that is called by this contract to finalize the payment for a domain.
     * Once the specific case is determined and `protocolFee` calculated, it calls ZNSTreasury to perform transfers.
    */
    function _processPayment(CoreRegisterArgs memory args) internal {
        // args.stakeFee can be 0
        uint256 protocolFee = rootPricer.getFeeForPrice(0x0, args.price + args.stakeFee);

        if (args.isStakePayment) { // for all root domains or subdomains with stake payment
            treasury.stakeForDomain(
                args.parentHash,
                args.domainHash,
                args.registrant,
                args.price,
                args.stakeFee,
                protocolFee
            );
        } else { // direct payment for subdomains
            treasury.processDirectPayment(
                args.parentHash,
                args.domainHash,
                args.registrant,
                args.price,
                protocolFee
            );
        }
    }

    /**
     * @notice This function is the main entry point for the Revoke flow.
     * Revokes a domain such as `0://wilder`.
     * Gets `tokenId` from casted domain hash to uint256, calls `ZNSDomainToken` to burn the token,
     * deletes the domain data from the `ZNSRegistry` and calls `ZNSTreasury` to unstake and withdraw funds
     * user staked for the domain. Emits a `DomainRevoked` event.
     * @dev > Note that we are not clearing the data in `ZNSAddressResolver` as it is considered not necessary
     * since none other contracts will have the domain data on them.
     * If we are not clearing `ZNSAddressResolver` state slots, we are making the next Register transaction
     * for the same name cheaper, since SSTORE on a non-zero slot costs 5k gas,
     * while SSTORE on a zero slot costs 20k gas.
     * If a user wants to clear his data from `ZNSAddressResolver`, he can call `ZNSAddressResolver` directly himself
     * BEFORE he calls to revoke, otherwise, `ZNSRegistry` owner check will fail, since the owner there
     * will be 0x0 address.
     * Also note that in order to Revoke, a caller has to be the owner of both:
     * Name (in `ZNSRegistry`) and Token (in `ZNSDomainToken`).
     * @param domainHash Hash of the domain to revoke
     */
    function revokeDomain(bytes32 domainHash)
    external
    override
    {
        require(
            isOwnerOf(domainHash, msg.sender, OwnerOf.BOTH),
            "ZNSRootRegistrar: Not the owner of both Name and Token"
        );

        subRegistrar.clearMintlistAndLock(domainHash);
        _coreRevoke(domainHash, msg.sender);
    }

    /**
     * @dev Internal part of the `revokeDomain()`. Called by this contract to finalize the Revoke flow of all domains.
     * It calls `ZNSDomainToken` to burn the token, deletes the domain data from the `ZNSRegistry` and
     * calls `ZNSTreasury` to unstake and withdraw funds user staked for the domain. Also emits
     * a `DomainRevoked` event.
    */
    function _coreRevoke(bytes32 domainHash, address owner) internal {
        uint256 tokenId = uint256(domainHash);
        domainToken.revoke(tokenId);
        registry.deleteRecord(domainHash);

        // check if user registered a domain with the stake
        (, uint256 stakedAmount) = treasury.stakedForDomain(domainHash);
        bool stakeRefunded = false;
        // send the stake back if it exists
        if (stakedAmount > 0) {
            uint256 protocolFee = rootPricer.getFeeForPrice(0x0, stakedAmount);

            treasury.unstakeForDomain(domainHash, owner, protocolFee);
            stakeRefunded = true;
        }

        emit DomainRevoked(domainHash, owner, stakeRefunded);
    }

    /**
     * @notice This function is the main entry point for the Reclaim flow. This flow is used to
     * reclaim full ownership of a domain (through becoming the owner of the Name) from the ownership of the Token.
     * This is used for different types of ownership transfers, such as:
     * - domain sale - a user will sell the Token, then the new owner has to call this function to reclaim the Name
     * - domain transfer - a user will transfer the Token, then the new owner
     * has to call this function to reclaim the Name
     *
     * A user needs to only be the owner of the Token to be able to Reclaim.
     * Updates the domain owner in the `ZNSRegistry` to the owner of the token and emits a `DomainReclaimed` event.
     */
    function reclaimDomain(bytes32 domainHash)
    external
    override
    {
        require(
            isOwnerOf(domainHash, msg.sender, OwnerOf.TOKEN),
            "ZNSRootRegistrar: Not the owner of the Token"
        );
        registry.updateDomainOwner(domainHash, msg.sender);

        emit DomainReclaimed(domainHash, msg.sender);
    }

    /**
     * @notice Function to validate that a given candidate is the owner of his Name, Token or both.
     * @param domainHash Hash of the domain to check
     * @param candidate Address of the candidate to check for ownership of the above domain's properties
     * @param ownerOf Enum value to determine which ownership to check for: NAME, TOKEN, BOTH
    */
    function isOwnerOf(bytes32 domainHash, address candidate, OwnerOf ownerOf) public view override returns (bool) {
        if (ownerOf == OwnerOf.NAME) {
            return candidate == registry.getDomainOwner(domainHash);
        } else if (ownerOf == OwnerOf.TOKEN) {
            return candidate == domainToken.ownerOf(uint256(domainHash));
        } else if (ownerOf == OwnerOf.BOTH) {
            return candidate == registry.getDomainOwner(domainHash)
                && candidate == domainToken.ownerOf(uint256(domainHash));
        }

        revert("Wrong enum value for `ownerOf`");
    }

    /**
     * @notice Setter function for the `ZNSRegistry` address in state.
     * Only ADMIN in `ZNSAccessController` can call this function.
     * @param registry_ Address of the `ZNSRegistry` contract
     */
    function setRegistry(address registry_) public override(ARegistryWired, IZNSRootRegistrar) onlyAdmin {
        _setRegistry(registry_);
    }

    /**
     * @notice Setter for the IZNSPricer type contract that Zero chooses to handle Root Domains.
     * Only ADMIN in `ZNSAccessController` can call this function.
     * @param rootPricer_ Address of the IZNSPricer type contract to set as pricer of Root Domains
    */
    function setRootPricer(address rootPricer_) public override onlyAdmin {
        require(
            rootPricer_ != address(0),
            "ZNSRootRegistrar: rootPricer_ is 0x0 address"
        );
        rootPricer = IZNSPricer(rootPricer_);

        emit RootPricerSet(rootPricer_);
    }

    /**
     * @notice Setter function for the `ZNSTreasury` address in state.
     * Only ADMIN in `ZNSAccessController` can call this function.
     * @param treasury_ Address of the `ZNSTreasury` contract
     */
    function setTreasury(address treasury_) public override onlyAdmin {
        require(
            treasury_ != address(0),
            "ZNSRootRegistrar: treasury_ is 0x0 address"
        );
        treasury = IZNSTreasury(treasury_);

        emit TreasurySet(treasury_);
    }

    /**
     * @notice Setter function for the `ZNSDomainToken` address in state.
     * Only ADMIN in `ZNSAccessController` can call this function.
     * @param domainToken_ Address of the `ZNSDomainToken` contract
     */
    function setDomainToken(address domainToken_) public override onlyAdmin {
        require(
            domainToken_ != address(0),
            "ZNSRootRegistrar: domainToken_ is 0x0 address"
        );
        domainToken = IZNSDomainToken(domainToken_);

        emit DomainTokenSet(domainToken_);
    }

    /**
     * @notice Setter for `ZNSSubRegistrar` contract. Only ADMIN in `ZNSAccessController` can call this function.
     * @param subRegistrar_ Address of the `ZNSSubRegistrar` contract
    */
    function setSubRegistrar(address subRegistrar_) external override onlyAdmin {
        require(subRegistrar_ != address(0), "ZNSRootRegistrar: subRegistrar_ is 0x0 address");

        subRegistrar = IZNSSubRegistrar(subRegistrar_);
        emit SubRegistrarSet(subRegistrar_);
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
