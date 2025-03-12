// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./ISmartVault.sol";
import "./IStrategyRegistry.sol";

/**
 * @notice Used when deposited assets are not the same length as underlying assets.
 */
error InvalidAssetLengths();

/**
 * @notice Gathers input for depositing assets.
 * @custom:member smartVault Smart vault for which the deposit is made.
 * @custom:member assets Amounts of assets being deposited.
 * @custom:member receiver Receiver of the deposit NFT.
 * @custom:member referral Referral address.
 * @custom:member doFlush If true, the smart vault will be flushed after the deposit as part of same transaction.
 */
struct DepositBag {
    address smartVault;
    uint256[] assets;
    address receiver;
    address referral;
    bool doFlush;
}

/**
 * @notice Gathers extra input for depositing assets.
 * @custom:member depositor Address making the deposit.
 * @custom:member tokens Tokens of the smart vault.
 * @custom:member strategies Strategies of the smart vault.
 * @custom:member allocations Set allocation of funds between strategies.
 * @custom:member flushIndex Current flush index of the smart vault.
 */
struct DepositExtras {
    address depositor;
    address[] tokens;
    address[] strategies;
    uint16a16 allocations;
    uint256 flushIndex;
}

/**
 * @notice Gathers return values of syncing deposits.
 * @custom:member mintedSVTs Amount of SVTs minted.
 * @custom:member dhwTimestamp Timestamp of the last DHW synced.
 * @custom:member feeSVTs Amount of SVTs minted as fees.
 * @custom:member sstShares Amount of SSTs claimed for each strategy.
 */
struct DepositSyncResult {
    uint256 mintedSVTs;
    uint256 dhwTimestamp;
    uint256 feeSVTs;
    uint256[] sstShares;
}

//  * @param smartVault Smart Vault address
//  * @param bag flush index, lastDhwSyncedTimestamp, oldTotalSVTs
//  * @param strategies strategy addresses
//  * @param assetGroup vault asset group token addresses
//  * @param dhwIndexes DHW Indexes for given flush index
//  * @param dhwIndexesOld DHW Indexes for previous flush index
//  * @param fees smart vault fee configuration
//  * @return syncResult Result of the smart vault sync.
struct SimulateDepositParams {
    address smartVault;
    // bag[0]: flushIndex,
    // bag[1]: lastDhwSyncedTimestamp,
    // bag[2]: oldTotalSVTs,
    uint256[3] bag;
    address[] strategies;
    address[] assetGroup;
    uint16a16 dhwIndexes;
    uint16a16 dhwIndexesOld;
    SmartVaultFees fees;
}

/**
 * @param mintedVaultShares Minted vault shares at given flush index
 * @param flushSvtSupply Total supply of SVTs for vault at given flush index
 */
struct FlushShares {
    uint128 mintedVaultShares;
    uint128 flushSvtSupply;
}

interface IDepositManager {
    /**
     * @notice User redeemed deposit NFTs for SVTs
     * @param smartVault Smart vault address
     * @param claimer Claimer address
     * @param claimedVaultTokens Amount of SVTs claimed
     * @param nftIds NFTs to burn
     * @param nftAmounts NFT shares to burn
     */
    event SmartVaultTokensClaimed(
        address indexed smartVault,
        address indexed claimer,
        uint256 claimedVaultTokens,
        uint256[] nftIds,
        uint256[] nftAmounts
    );

    /**
     * @notice A deposit has been initiated
     * @param smartVault Smart vault address
     * @param receiver Beneficiary of the deposit
     * @param depositId Deposit NFT ID for this deposit
     * @param flushIndex Flush index the deposit was scheduled for
     * @param assets Amount of assets to deposit
     * @param depositor Address that initiated the deposit
     * @param referral Referral address
     */
    event DepositInitiated(
        address indexed smartVault,
        address indexed receiver,
        uint256 indexed depositId,
        uint256 flushIndex,
        uint256[] assets,
        address depositor,
        address referral
    );

    /**
     * @notice Simulate vault synchronization (i.e. DHW was completed, but vault wasn't synced yet)
     */
    function syncDepositsSimulate(SimulateDepositParams calldata parameters)
        external
        view
        returns (DepositSyncResult memory syncResult);

    /**
     * @notice Synchronize vault deposits for completed DHW runs
     * @dev Requirements:
     * - caller must have role ROLE_SMART_VAULT_MANAGER
     * @param smartVault Smart Vault address
     * @param bag flushIndex, lastDhwSyncedTimestamp, oldTotalSVTs
     * @param strategies vault strategy addresses
     * @param dhwIndexes dhw indexes for given and previous flushIndex
     * @param assetGroup vault asset group token addresses
     * @param fees smart vault fee configuration
     * @return syncResult Result of the smart vault sync.
     */
    function syncDeposits(
        address smartVault,
        uint256[3] calldata bag,
        // uint256 flushIndex,
        // uint256 lastDhwSyncedTimestamp,
        // uint256 oldTotalSVTs,
        address[] calldata strategies,
        uint16a16[2] calldata dhwIndexes,
        address[] calldata assetGroup,
        SmartVaultFees calldata fees
    ) external returns (DepositSyncResult memory syncResult);

    /**
     * @notice Adds deposits for the next flush cycle.
     * @dev Requirements:
     * - caller must have role ROLE_SMART_VAULT_MANAGER
     * @param bag Deposit parameters.
     * @param bag2 Extra parameters.
     * @return deposits Amount of assets deposited.
     * @return nftId ID of the deposit NFT.
     */
    function depositAssets(DepositBag calldata bag, DepositExtras calldata bag2)
        external
        returns (uint256[] memory deposits, uint256 nftId);

    /**
     * @notice Mark deposits ready to be processed in the next DHW cycle
     * @dev Requirements:
     * - caller must have role ROLE_SMART_VAULT_MANAGER
     * @param smartVault Smart Vault address
     * @param flushIndex index to flush
     * @param strategies vault strategy addresses
     * @param allocations vault strategy allocations
     * @param tokens vault asset group token addresses
     * @return dhwIndexes DHW indexes in which the deposits will be included
     */
    function flushSmartVault(
        address smartVault,
        uint256 flushIndex,
        address[] calldata strategies,
        uint16a16 allocations,
        address[] calldata tokens
    ) external returns (uint16a16 dhwIndexes);

    /**
     * @notice Get the number of SVTs that are available, but haven't been claimed yet, for the given NFT
     * @param smartVaultAddress Smart Vault address
     * @param data NFT deposit NFT metadata
     * @param nftShares amount of NFT shares to burn for SVTs
     * @param mintedSVTs amount of SVTs minted for this flush
     * @param tokens vault asset group addresses
     */
    function getClaimedVaultTokensPreview(
        address smartVaultAddress,
        DepositMetadata memory data,
        uint256 nftShares,
        uint256 mintedSVTs,
        address[] calldata tokens
    ) external view returns (uint256);

    /**
     * @notice Fetch assets deposited in a given vault flush
     */
    function smartVaultDeposits(address smartVault, uint256 flushIdx, uint256 assetGroupLength)
        external
        view
        returns (uint256[] memory);

    /**
     * @notice Claim SVTs by burning deposit NFTs.
     * @dev Requirements:
     * - caller must have role ROLE_SMART_VAULT_MANAGER
     * @param smartVault Smart Vault address
     * @param nftIds NFT ids to burn
     * @param nftAmounts NFT amounts to burn (support for partial burn)
     * @param tokens vault asset group token addresses
     * @param executor address executing the claim transaction
     * @return claimedTokens Amount of smart vault tokens claimed.
     */
    function claimSmartVaultTokens(
        address smartVault,
        uint256[] calldata nftIds,
        uint256[] calldata nftAmounts,
        address[] calldata tokens,
        address executor
    ) external returns (uint256 claimedTokens);
}
