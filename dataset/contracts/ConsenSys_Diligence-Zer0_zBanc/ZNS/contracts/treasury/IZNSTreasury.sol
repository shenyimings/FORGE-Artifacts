// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/** 
 * @notice The `PaymentConfig` struct describes the two pieces of information
 * needed to create a payment configuration for a domain. The address of the
 * user to send funds to in a sale, and what token those funds are in.
 */
struct PaymentConfig {
    IERC20 token;
    // feeBeneficiary if STAKE, paymentBeneficiary if DIRECT
    address beneficiary;
}


/**
 * @title IZNSTreasury.sol - Interface for the ZNSTreasury contract responsible for managing payments and staking.
 * @dev Below are docs for the types in this file:
 *  - `PaymentConfig`: Struct containing data for the payment configuration of the parent distributing subdomains:
 *      + `token`: The address of the ERC-20 compliant payment token contract chosen by the parent
 *      + `beneficiary`: The address of the beneficiary contract or wallet that will receive payments or fees
 *  - `Stake`: Struct containing data for the staking of a domain written at the time of staking:
 *      + `token`: The address of the ERC-20 compliant staking token used to deposit a specific stake for domain
 *      + `amount`: The amount of the staking token above deposited by the user
*/
interface IZNSTreasury {

    /**
     * @notice Describe a stake for a domain. This could be 
     * in any ERC20 token so the address of the specific token
     * as well as the amount is required.
     */
    struct Stake {
        IERC20 token;
        uint256 amount;
    }

    /**
     * @notice Emitted when a new stake is deposited upon registration of a new domain.
     * @param domainHash The hash of the domain name
     * @param depositor The address of the depositing user / new domain owner
     * @param stakeAmount The amount they are depositing / price of the domain based on name length
     * @param stakeFee The registration fee paid by the user on top of the staked amount
     */
    event StakeDeposited(
        bytes32 indexed parentHash,
        bytes32 indexed domainHash,
        address indexed depositor,
        address stakingToken,
        uint256 stakeAmount,
        uint256 stakeFee,
        uint256 protocolFee
    );

    /**
     * @notice Emitted when a stake is withdrawn upon domain revocation.
     * @param domainHash The hash of the domain name being revoked
     * @param owner The owner of the domain being revoked
     * @param stakeAmount The staked amount withdrawn to the user after revoking
     */
    event StakeWithdrawn(
        bytes32 indexed domainHash,
        address indexed owner,
        address indexed stakingToken,
        uint256 stakeAmount
    );

    /**
     * @notice Emitted when a direct payment is processed upon registration of a new domain.
     * @param parentHash The hash of the parent domain
     * @param domainHash The full namehash of the domain registered
     * @param payer The address of the user who paid for the domain
     * @param beneficiary The address of the beneficiary contract or wallet that received the payment
     * @param amount The amount paid by the user
     * @param protocolFee The protocol fee paid by the user to Zero
    */
    event DirectPaymentProcessed(
        bytes32 indexed parentHash,
        bytes32 indexed domainHash,
        address indexed payer,
        address beneficiary,
        uint256 amount,
        uint256 protocolFee
    );

    /**
     * @notice Emitted when `curvePricer` is set in state.
     * @param curvePricer The new address of the CurvePricer contract
     */
    event CurvePricerSet(address curvePricer);

    /**
     * @notice Emitted when `stakingToken` is set in state.
     * @param token The new address of the ERC-20 compliant payment token contract
     */
    event PaymentTokenSet(bytes32 indexed domainHash, address indexed token);

    /**
     * @notice Emitted when `zeroVault` is set in state.
     * @param beneficiary The new address of the beneficiary contract or wallet
     */
    event BeneficiarySet(bytes32 indexed domainHash, address indexed beneficiary);

    function paymentConfigs(
        bytes32 domainHash
    ) external view returns (
        IERC20 token,
        address beneficiary
    );

    function stakedForDomain(bytes32 domainHash) external view returns (IERC20, uint256);

    function stakeForDomain(
        bytes32 parentHash,
        bytes32 domainHash,
        address depositor,
        uint256 stakeAmount,
        uint256 stakeFee,
        uint256 protocolFee
    ) external;

    function unstakeForDomain(
        bytes32 domainHash,
        address owner,
        uint256 protocolFee
    ) external;

    function processDirectPayment(
        bytes32 parentHash,
        bytes32 domainHash,
        address payer,
        uint256 paymentAmount,
        uint256 protocolFee
    ) external;

    function setPaymentConfig(
        bytes32 domainHash,
        PaymentConfig memory paymentConfig
    ) external;

    function setBeneficiary(
        bytes32 domainHash,
        address beneficiary
    ) external;

    function setPaymentToken(
        bytes32 domainHash,
        address paymentToken
    ) external;

    function setRegistry(address registry_) external;

    function initialize(
        address accessController_,
        address curvePricer_,
        address stakingToken_,
        address zeroVault_
    ) external;
}
