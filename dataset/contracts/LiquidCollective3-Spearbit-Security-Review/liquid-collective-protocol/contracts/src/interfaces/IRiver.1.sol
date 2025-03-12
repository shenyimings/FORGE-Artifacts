//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/river/DailyCommittableLimits.sol";

import "./components/IConsensusLayerDepositManager.1.sol";
import "./components/IOracleManager.1.sol";
import "./components/ISharesManager.1.sol";
import "./components/IUserDepositManager.1.sol";

/// @title River Interface (v1)
/// @author Kiln
/// @notice The main system interface
interface IRiverV1 is IConsensusLayerDepositManagerV1, IUserDepositManagerV1, ISharesManagerV1, IOracleManagerV1 {
    /// @notice Funds have been pulled from the Execution Layer Fee Recipient
    /// @param amount The amount pulled
    event PulledELFees(uint256 amount);

    /// @notice Funds have been pulled from the Coverage Fund
    /// @param amount The amount pulled
    event PulledCoverageFunds(uint256 amount);

    /// @notice The stored Execution Layer Fee Recipient has been changed
    /// @param elFeeRecipient The new Execution Layer Fee Recipient
    event SetELFeeRecipient(address indexed elFeeRecipient);

    /// @notice The stored Coverage Fund has been changed
    /// @param coverageFund The new Coverage Fund
    event SetCoverageFund(address indexed coverageFund);

    /// @notice The stored Collector has been changed
    /// @param collector The new Collector
    event SetCollector(address indexed collector);

    /// @notice The stored Allowlist has been changed
    /// @param allowlist The new Allowlist
    event SetAllowlist(address indexed allowlist);

    /// @notice The stored Global Fee has been changed
    /// @param fee The new Global Fee
    event SetGlobalFee(uint256 fee);

    /// @notice The stored Operators Registry has been changed
    /// @param operatorRegistry The new Operators Registry
    event SetOperatorsRegistry(address indexed operatorRegistry);

    /// @notice The stored Metadata URI string has been changed
    /// @param metadataURI The new Metadata URI string
    event SetMetadataURI(string metadataURI);

    /// @notice The system underlying supply increased. This is a snapshot of the balances for accounting purposes
    /// @param _collector The address of the collector during this event
    /// @param _oldTotalUnderlyingBalance Old total ETH balance under management by River
    /// @param _oldTotalSupply Old total supply in shares
    /// @param _newTotalUnderlyingBalance New total ETH balance under management by River
    /// @param _newTotalSupply New total supply in shares
    event RewardsEarned(
        address indexed _collector,
        uint256 _oldTotalUnderlyingBalance,
        uint256 _oldTotalSupply,
        uint256 _newTotalUnderlyingBalance,
        uint256 _newTotalSupply
    );

    /// @notice Emitted when the daily committable limits are changed
    /// @param maxNetAmount The maximum net amount that can be committed daily
    /// @param maxRelativeAmount The maximum amount relative to the total underlying supply that can be committed daily
    event SetMaxDailyCommittableAmounts(uint256 maxNetAmount, uint256 maxRelativeAmount);

    /// @notice Emitted when the redeem manager address is changed
    /// @param redeemManager The address of the redeem manager
    event SetRedeemManager(address redeemManager);

    /// @notice Emitted when funds are pulled from the redeem manager
    /// @param amount The amount pulled
    event PulledRedeemManagerExceedingEth(uint256 amount);

    /// @notice Emitted when the balance to deposit is updated
    /// @param oldAmount The old balance to deposit
    /// @param newAmount The new balance to deposit
    event SetBalanceToDeposit(uint256 oldAmount, uint256 newAmount);

    /// @notice Emitted when the balance to redeem is updated
    /// @param oldAmount The old balance to redeem
    /// @param newAmount The new balance to redeem
    event SetBalanceToRedeem(uint256 oldAmount, uint256 newAmount);

    /// @notice Emitted when the balance committed to deposit
    /// @param oldAmount The old balance committed to deposit
    /// @param newAmount The new balance committed to deposit
    event SetBalanceCommittedToDeposit(uint256 oldAmount, uint256 newAmount);

    /// @notice Emitted when the redeem manager received a withdraw event report
    /// @param redeemManagerDemand The total demand in LsETH of the redeem manager
    /// @param suppliedRedeemManagerDemand The amount of LsETH demand actually supplied
    /// @param suppliedRedeemManagerDemandInEth The amount in ETH of the supplied demand
    event ReportedRedeemManager(
        uint256 redeemManagerDemand, uint256 suppliedRedeemManagerDemand, uint256 suppliedRedeemManagerDemandInEth
    );

    /// @notice Thrown when the amount received from the Withdraw contract doe not match the requested amount
    /// @param requested The amount that was requested
    /// @param received The amount that was received
    error InvalidPulledClFundsAmount(uint256 requested, uint256 received);

    /// @notice The computed amount of shares to mint is 0
    error ZeroMintedShares();

    /// @notice The access was denied
    /// @param account The account that was denied
    error Denied(address account);

    /// @notice Initializes the River system
    /// @param _depositContractAddress Address to make Consensus Layer deposits
    /// @param _elFeeRecipientAddress Address that receives the execution layer fees
    /// @param _withdrawalCredentials Credentials to use for every validator deposit
    /// @param _oracleAddress The address of the Oracle contract
    /// @param _systemAdministratorAddress Administrator address
    /// @param _allowlistAddress Address of the allowlist contract
    /// @param _operatorRegistryAddress Address of the operator registry
    /// @param _collectorAddress Address receiving the the global fee on revenue
    /// @param _globalFee Amount retained when the ETH balance increases and sent to the collector
    function initRiverV1(
        address _depositContractAddress,
        address _elFeeRecipientAddress,
        bytes32 _withdrawalCredentials,
        address _oracleAddress,
        address _systemAdministratorAddress,
        address _allowlistAddress,
        address _operatorRegistryAddress,
        address _collectorAddress,
        uint256 _globalFee
    ) external;

    /// @notice Initialized version 1.1 of the River System
    /// @param _redeemManager The redeem manager address
    /// @param epochsPerFrame The amounts of epochs in a frame
    /// @param slotsPerEpoch The slots inside an epoch
    /// @param secondsPerSlot The seconds inside a slot
    /// @param genesisTime The genesis timestamp
    /// @param epochsToAssumedFinality The number of epochs before an epoch is considered final on-chain
    /// @param annualAprUpperBound The reporting upper bound
    /// @param relativeLowerBound The reporting lower bound
    /// @param maxDailyNetCommittableAmount_ The net daily committable limit
    /// @param maxDailyRelativeCommittableAmount_ The relative daily committable limit
    function initRiverV1_1(
        address _redeemManager,
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint64 epochsToAssumedFinality,
        uint256 annualAprUpperBound,
        uint256 relativeLowerBound,
        uint128 maxDailyNetCommittableAmount_,
        uint128 maxDailyRelativeCommittableAmount_
    ) external;

    /// @notice Get the current global fee
    /// @return The global fee
    function getGlobalFee() external view returns (uint256);

    /// @notice Retrieve the allowlist address
    /// @return The allowlist address
    function getAllowlist() external view returns (address);

    /// @notice Retrieve the collector address
    /// @return The collector address
    function getCollector() external view returns (address);

    /// @notice Retrieve the execution layer fee recipient
    /// @return The execution layer fee recipient address
    function getELFeeRecipient() external view returns (address);

    /// @notice Retrieve the coverage fund
    /// @return The coverage fund address
    function getCoverageFund() external view returns (address);

    /// @notice Retrieve the operators registry
    /// @return The operators registry address
    function getOperatorsRegistry() external view returns (address);

    /// @notice Retrieve the metadata uri string value
    /// @return The metadata uri string value
    function getMetadataURI() external view returns (string memory);

    /// @notice Retrieve the configured daily committable limits
    /// @return The daily committable limits structure
    function getDailyCommittableLimits()
        external
        view
        returns (DailyCommittableLimits.DailyCommittableLimitsStruct memory);

    /// @notice Resolves the provided redeem requests by calling the redeem manager
    /// @param redeemRequestIds The list of redeem requests to resolve
    /// @return withdrawalEventIds The list of matching withdrawal events, or error codes
    function resolveRedeemRequests(uint32[] calldata redeemRequestIds)
        external
        view
        returns (int64[] memory withdrawalEventIds);

    /// @notice Set the daily committable limits
    /// @param dcl The Daily Committable Limits structure
    function setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory dcl) external;

    /// @notice Retrieve the current balance to redeem
    /// @return The current balance to redeem
    function getBalanceToRedeem() external view returns (uint256);

    /// @notice Performs a redeem request on the redeem manager
    /// @param lsETHAmount The amount of LsETH to redeem
    /// @return redeemRequestId The ID of the newly created redeem request
    function requestRedeem(uint256 lsETHAmount) external returns (uint32 redeemRequestId);

    /// @notice Claims several redeem requests
    /// @param redeemRequestIds The list of redeem requests to claim
    /// @param withdrawalEventIds The list of resolved withdrawal event ids
    /// @return claimStatuses The operation status results
    function claimRedeemRequests(uint32[] calldata redeemRequestIds, uint32[] calldata withdrawalEventIds)
        external
        returns (uint8[] memory claimStatuses);

    /// @notice Changes the global fee parameter
    /// @param newFee New fee value
    function setGlobalFee(uint256 newFee) external;

    /// @notice Changes the allowlist address
    /// @param _newAllowlist New address for the allowlist
    function setAllowlist(address _newAllowlist) external;

    /// @notice Changes the collector address
    /// @param _newCollector New address for the collector
    function setCollector(address _newCollector) external;

    /// @notice Changes the execution layer fee recipient
    /// @param _newELFeeRecipient New address for the recipient
    function setELFeeRecipient(address _newELFeeRecipient) external;

    /// @notice Changes the coverage fund
    /// @param _newCoverageFund New address for the fund
    function setCoverageFund(address _newCoverageFund) external;

    /// @notice Sets the metadata uri string value
    /// @param _metadataURI The new metadata uri string value
    function setMetadataURI(string memory _metadataURI) external;

    /// @notice Input for execution layer fee earnings
    function sendELFees() external payable;

    /// @notice Input for consensus layer funds, containing both exit and skimming
    function sendCLFunds() external payable;

    /// @notice Input for coverage funds
    function sendCoverageFunds() external payable;

    /// @notice Input for the redeem manager funds
    function sendRedeemManagerExceedingFunds() external payable;
}
