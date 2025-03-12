// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IZNSTreasury } from "./IZNSTreasury.sol";
import { AAccessControlled } from "../access/AAccessControlled.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { PaymentConfig } from "./IZNSTreasury.sol";
import { ARegistryWired } from "../registry/ARegistryWired.sol";


/**
 * @title IZNSTreasury.sol - Interface for the ZNSTreasury contract responsible for managing payments and staking.
 * @dev This contract is not also the performer of all transfers, but it also stores staked funds for ALL domains
 * that use PaymentType.STAKE. This is to ensure that the funds are not locked in the domain owner's wallet,
 * but are held within the system and users do not have access to them while their respective domains are active.
 * It also stores the payment configurations for all domains and staked amounts and token addresses which were used.
 * This information is needed for revoking users to withdraw their stakes back when they exit the system.
*/
contract ZNSTreasury is AAccessControlled, ARegistryWired, UUPSUpgradeable, IZNSTreasury {
    using SafeERC20 for IERC20;

    /**
     * @notice The mapping that stores the payment configurations for each domain.
     * Zero's own configs for root domains is stored under 0x0 hash.
    */
    mapping(bytes32 domainHash => PaymentConfig config) public override paymentConfigs;

    /**
     * @notice The mapping that stores `Stake` struct mapped by domainHash. It stores the staking data for
     * each domain in zNS. Note that there is no owner address to which the stake is tied to. Instead, the
     * owner data from `ZNSRegistry` is used to identify a user who owns the stake. So the staking data is
     * tied to the owner of the Name. This should be taken into account, since any transfer of the Token to
     * another address, and the system, allowing them to Reclaim the Name, will also allow them to withdraw the stake.
     * > Stake is owned by the owner of the Name in `ZNSRegistry` which the owner of the Token can reclaim!
     */
    mapping(bytes32 domainHash => Stake stakeData) public override stakedForDomain;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice `ZNSTreasury` proxy state initializer. Note that setter functions are used
     * instead of direct state variable assignments in order to use proper Access Control
     * at initialization. Only ADMIN in `ZNSAccessController` can call this function.
     * For this also, it is important that `ZNSAccessController` is deployed and initialized with role data
     * before this contract is deployed.
     * @param accessController_ The address of the `ZNSAccessController` contract.
     * @param registry_ The address of the `ZNSRegistry` contract.
     * @param paymentToken_ The address of the staking token (currently $ZERO).
     * @param zeroVault_ The address of the Zero Vault - the wallet or contract to collect all the registration fees.
     */
    function initialize(
        address accessController_,
        address registry_,
        address paymentToken_,
        address zeroVault_
    ) external override initializer {
        _setAccessController(accessController_);
        _setRegistry(registry_);

        require(
            paymentToken_ != address(0),
            "ZNSTreasury: paymentToken_ passed as 0x0 address"
        );
        require(
            zeroVault_ != address(0),
            "ZNSTreasury: zeroVault_ passed as 0x0 address"
        );

        paymentConfigs[0x0] = PaymentConfig({
            token: IERC20(paymentToken_),
            beneficiary : zeroVault_
        });
    }

    /**
     * @notice Performs all the transfers for the staking payment. This function is called by `ZNSRootRegistrar.sol`
     * when a user wants to register a domain. It transfers the stake amount and the registration fee
     * to the contract from the user, and records the staked amount for the domain.
     * Note that a user has to approve the correct amount of `domainPrice + stakeFee + protocolFee`
     * for this function to not revert.
     *
     * Reads parent's payment config from state and transfers the stake amount and all fees to this contract.
     * After that transfers the protocol fee to the Zero Vault from this contract to respective beneficiaries.
     * After transfers have been performed, saves the staking data into `stakedForDomain[domainHash]`
     * and fires a `StakeDeposited` event.
     * @param parentHash The hash of the parent domain.
     * @param domainHash The hash of the domain for which the stake is being deposited.
     * @param depositor The address of the user who is depositing the stake.
     * @param stakeAmount The amount of the staking token to be deposited.
     * @param stakeFee The registration fee paid by the user on top of the staked amount to the parent domain owner.
     * @param protocolFee The protocol fee paid by the user to Zero.
     */
    function stakeForDomain(
        bytes32 parentHash,
        bytes32 domainHash,
        address depositor,
        uint256 stakeAmount,
        uint256 stakeFee,
        uint256 protocolFee
    ) external override onlyRegistrar {
        PaymentConfig memory parentConfig = paymentConfigs[parentHash];

        // Transfer stake amount and fees to this address
        parentConfig.token.safeTransferFrom(
            depositor,
            address(this),
            stakeAmount + stakeFee + protocolFee
        );

        // Transfer registration fee to the Zero Vault from this address
        parentConfig.token.safeTransfer(
            paymentConfigs[0x0].beneficiary,
            protocolFee
        );

        // transfer stake fee to the parent beneficiary if it's > 0
        if (stakeFee > 0) {
            require(
                parentConfig.beneficiary != address(0),
                "ZNSTreasury: parent domain has no beneficiary set"
            );

            parentConfig.token.safeTransfer(
                parentConfig.beneficiary,
                stakeFee
            );
        }

        // Record staked amount for this domain
        stakedForDomain[domainHash] = Stake({
            token: parentConfig.token,
            amount: stakeAmount
        });

        emit StakeDeposited(
            parentHash,
            domainHash,
            depositor,
            address(parentConfig.token),
            stakeAmount,
            stakeFee,
            protocolFee
        );
    }

    /**
     * @notice Withdraws the stake for a domain. This function is called by `ZNSRootRegistrar.sol`
     * when a user wants to Revoke a domain. It transfers the stake amount from the contract back to the user,
     * and deletes the stake data for the domain in state. Only REGISTRAR_ROLE can call this function.
     * Emits a `StakeWithdrawn` event.
     * Since we are clearing storage, gas refund from this operation makes Revoke transactions cheaper.
     * @param domainHash The hash of the domain for which the stake is being withdrawn.
     * @param owner The address of the user who is withdrawing the stake.
     * @param protocolFee The protocol fee paid by the user to Zero.
     */
    function unstakeForDomain(
        bytes32 domainHash,
        address owner,
        uint256 protocolFee
    ) external override onlyRegistrar {
        Stake memory stakeData = stakedForDomain[domainHash];
        delete stakedForDomain[domainHash];

        if (protocolFee > 0) {
            stakeData.token.safeTransferFrom(
                owner,
                paymentConfigs[0x0].beneficiary,
                protocolFee
            );
        }

        stakeData.token.safeTransfer(owner, stakeData.amount);

        emit StakeWithdrawn(
            domainHash,
            owner,
            address(stakeData.token),
            stakeData.amount
        );
    }

    /**
     * @notice An alternative to `stakeForDomain()` for cases when a parent domain is using PaymentType.DIRECT.
     * @dev Note that `stakeFee` transfers are NOT present here, since a fee on top of the price is ONLY supported
     * for STAKE payment type. This function is called by `ZNSRootRegistrar.sol` when a user wants to register a domain.
     * This function uses a different approach than `stakeForDomain()` as it performs 2 transfers from the user's
     * wallet. Is uses `paymentConfigs[parentHash]` to get the token and beneficiary for the parent domain.
     * Can be called ONLY by the REGISTRAR_ROLE. Fires a `DirectPaymentProcessed` event.
     * @param parentHash The hash of the parent domain.
     * @param domainHash The hash of the domain for which the stake is being deposited.
     * @param payer The address of the user who is paying for the domain.
     * @param paymentAmount The amount of the payment token to be deposited.
     * @param protocolFee The protocol fee paid by the user to Zero.
    */
    function processDirectPayment(
        bytes32 parentHash,
        bytes32 domainHash,
        address payer,
        uint256 paymentAmount,
        uint256 protocolFee
    ) external override onlyRegistrar {
        PaymentConfig memory parentConfig = paymentConfigs[parentHash];

        require(
            parentConfig.beneficiary != address(0),
            "ZNSTreasury: parent domain has no beneficiary set"
        );

        // Transfer payment to parent beneficiary from payer
        parentConfig.token.safeTransferFrom(
            payer,
            parentConfig.beneficiary,
            paymentAmount
        );

        // Transfer registration fee to the Zero Vault from payer
        parentConfig.token.safeTransferFrom(
            payer,
            paymentConfigs[0x0].beneficiary,
            protocolFee
        );

        emit DirectPaymentProcessed(
            parentHash,
            domainHash,
            payer,
            parentConfig.beneficiary,
            paymentAmount,
            protocolFee
        );
    }

    /**
     * @notice Setter function for the `paymentConfig` chosen by domain owner.
     * Only domain owner/operator can call this.
     * @param domainHash The hash of the domain to set payment config for
     * @param paymentConfig The payment config to be set for the domain (see IZNSTreasury.sol for details)
    */
    function setPaymentConfig(
        bytes32 domainHash,
        PaymentConfig memory paymentConfig
    ) external override {
        require(
            registry.isOwnerOrOperator(domainHash, msg.sender) || accessController.isRegistrar(msg.sender),
            "ZNSTreasury: Not authorized."
        );
        _setBeneficiary(domainHash, paymentConfig.beneficiary);
        _setPaymentToken(domainHash, address(paymentConfig.token));
    }

    /**
     * @notice Setter function for the `PaymentConfig.beneficiary` address chosen by domain owner.
     * Only domain owner/operator can call this. Fires a `BeneficiarySet` event.
     * @param domainHash The hash of the domain to set beneficiary for
     * @param beneficiary The address of the new beneficiary
     *  - the wallet or contract to collect all payments for the domain.
     */
    function setBeneficiary(
        bytes32 domainHash,
        address beneficiary
    ) public override onlyOwnerOrOperator(domainHash) {
        _setBeneficiary(domainHash, beneficiary);
    }

    /**
     * @notice Setter function for the `PaymentConfig.token` chosen by the domain owner.
     * Only domain owner/operator can call this. Fires a `PaymentTokenSet` event.
     * @param domainHash The hash of the domain to set payment token for
     * @param paymentToken The address of the new payment/staking token
     */
    function setPaymentToken(
        bytes32 domainHash,
        address paymentToken
    ) public override onlyOwnerOrOperator(domainHash) {
        _setPaymentToken(domainHash, paymentToken);
    }

    /**
     * @notice Sets the registry address in state.
     * @dev This function is required for all contracts inheriting `ARegistryWired`.
    */
    function setRegistry(
        address registry_
    ) external override(ARegistryWired, IZNSTreasury) onlyAdmin {
        _setRegistry(registry_);
    }

    function _setBeneficiary(bytes32 domainHash, address beneficiary) internal {
        require(beneficiary != address(0), "ZNSTreasury: beneficiary passed as 0x0 address");

        paymentConfigs[domainHash].beneficiary = beneficiary;
        emit BeneficiarySet(domainHash, beneficiary);
    }

    function _setPaymentToken(bytes32 domainHash, address paymentToken) internal {
        require(paymentToken != address(0), "ZNSTreasury: paymentToken passed as 0x0 address");

        paymentConfigs[domainHash].token = IERC20(paymentToken);
        emit PaymentTokenSet(domainHash, paymentToken);
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
