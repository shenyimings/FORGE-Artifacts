// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./IDepositManager.sol";
import "./ISmartVault.sol";
import "./ISwapper.sol";
import "./IWithdrawalManager.sol";

/* ========== ERRORS ========== */

/**
 * @notice Used when trying to claim SVTs for deposit that was not synced yet.
 */
error DepositNotSyncedYet();

/**
 * @notice Used when user has insufficient balance for redeemal of shares.
 */
error InsufficientBalance(uint256 available, uint256 required);

/**
 * @notice Used when there is nothing to flush.
 */
error NothingToFlush();

/**
 * @notice Used when trying to register a smart vault that was already registered.
 */
error SmartVaultAlreadyRegistered();

/**
 * @notice Used when trying to perform an action for smart vault that was not registered yet.
 */
error SmartVaultNotRegisteredYet();

/**
 * @notice Used when user tries to configure a vault with too large management fee.
 */
error ManagementFeeTooLarge(uint256 mgmtFeePct);

/**
 * @notice Used when user tries to configure a vault with too large performance fee.
 */
error PerformanceFeeTooLarge(uint256 performanceFeePct);

/**
 * @notice Used when strategies provided for reallocation are invalid.
 */
error InvalidStrategies();

/**
 * @notice Used when smart vault in reallocation has statically set allocation.
 */
error StaticAllocationSmartVault();

/**
 * @notice Used when user tries to configure a vault with too large deposit fee.
 */
error DepositFeeTooLarge(uint256 depositFeePct);

/**
 * @notice Used when user tries to flush a vault, but DHW indexes overlap with previous flush
 */
error FlushOverlap(address strategy);

/**
 * @notice Used when user tries redeem on behalf of another user, but the vault does not support it
 */
error RedeemForNotAllowed();

/* ========== STRUCTS ========== */

/**
 * @notice Struct holding all data for registration of smart vault.
 * @custom:member assetGroupId Underlying asset group of the smart vault.
 * @custom:member strategies Strategies used by the smart vault.
 * @custom:member strategyAllocation Optional. If empty array, values will be calculated on the spot.
 * @custom:member managementFeePct Management fee of the smart vault.
 * @custom:member depositFeePct Deposit fee of the smart vault.
 * @custom:member performanceFeePct Performance fee of the smart vault.
 */
struct SmartVaultRegistrationForm {
    uint256 assetGroupId;
    address[] strategies;
    uint16a16 strategyAllocation;
    uint16 managementFeePct;
    uint16 depositFeePct;
    uint16 performanceFeePct;
}

/**
 * @notice Parameters for reallocation.
 * @custom:member smartVaults Smart vaults to reallocate.
 * @custom:member strategies Set of strategies involved in the reallocation.
 * @custom:member swapInfo Information for swapping assets before depositing into the protocol.
 * @custom:member depositSlippages Slippages used to constrain depositing into the protocol.
 * @custom:member withdrawalSlippages Slippages used to contrain withdrawal from the protocol.
 * @custom:member exchangeRateSlippages Slippages used to constratrain exchange rates for asset tokens.
 */
struct ReallocateParamBag {
    address[] smartVaults;
    address[] strategies;
    SwapInfo[][] swapInfo;
    uint256[][] depositSlippages;
    uint256[][] withdrawalSlippages;
    uint256[2][] exchangeRateSlippages;
}

struct FlushIndex {
    uint128 current;
    uint128 toSync;
}

/* ========== INTERFACES ========== */

interface ISmartVaultBalance {
    /**
     * @notice Retrieves user balance of smart vault tokens.
     * @param smartVault Smart vault.
     * @param user User to check.
     * @return balance SVT balance of user for smart vault.
     */
    function getUserSVTBalance(address smartVault, address user) external view returns (uint256 balance);

    /**
     * @notice Retrieves total supply of SVTs.
     * Includes deposits that were processed by DHW, but still need SVTs to be minted.
     * @param smartVault Smart Vault address.
     * @return totalSupply Simulated total supply
     */
    function getSVTTotalSupply(address smartVault) external view returns (uint256 totalSupply);
}

interface ISmartVaultRegistry {
    /**
     * @notice Registers smart vault into the Spool protocol.
     * @dev Requirements:
     * - caller must have role ROLE_SMART_VAULT_INTEGRATOR
     * @param smartVault Smart vault to register.
     * @param registrationForm Form with information for registration.
     */
    function registerSmartVault(address smartVault, SmartVaultRegistrationForm calldata registrationForm) external;
}

interface ISmartVaultManager is ISmartVaultBalance, ISmartVaultRegistry {
    /* ========== EXTERNAL VIEW FUNCTIONS ========== */

    /**
     * @notice Gets do-hard-work indexes.
     * @param smartVault Smart vault.
     * @param flushIndex Flush index.
     * @return dhwIndexes Do-hard-work indexes for flush index of the smart vault.
     */
    function dhwIndexes(address smartVault, uint256 flushIndex) external view returns (uint16a16 dhwIndexes);

    /**
     * @notice Gets latest flush index for a smart vault.
     * @param smartVault Smart vault.
     * @return flushIndex Latest flush index for the smart vault.
     */
    function getLatestFlushIndex(address smartVault) external view returns (uint256 flushIndex);

    /**
     * @notice Gets strategy allocation for a smart vault.
     * @param smartVault Smart vault.
     * @return allocation Strategy allocation for the smart vault.
     */
    function allocations(address smartVault) external view returns (uint16a16 allocation);

    /**
     * @notice Gets strategies used by a smart vault.
     * @param smartVault Smart vault.
     * @return strategies Strategies for the smart vault.
     */
    function strategies(address smartVault) external view returns (address[] memory strategies);

    /**
     * @notice Gets asest group used by a smart vault.
     * @param smartVault Smart vault.
     * @return assetGroupId ID of the asset group used by the smart vault.
     */
    function assetGroupId(address smartVault) external view returns (uint256 assetGroupId);

    /* ========== EXTERNAL MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Flushes deposits and withdrawal for the next do-hard-work.
     * @param smartVault Smart vault to flush.
     */
    function flushSmartVault(address smartVault) external;

    /**
     * @notice Reallocates smart vaults.
     * @dev Requirements:
     * - caller must have a ROLE_REALLOCATOR role
     * - smart vaults must be registered
     * - smart vaults must use same asset group
     * - strategies must represent a set of strategies used by smart vaults
     * @param reallocateParams Paramaters for reallocation.
     */
    function reallocate(ReallocateParamBag calldata reallocateParams) external;

    /**
     * @notice Removes strategy from vaults, and optionally removes it from the system as well.
     * @dev Requirements:
     * - caller must have role ROLE_SPOOL_ADMIN
     * @param strategy Strategy address to remove.
     * @param fromVaultsOnly Whether to remove the strategy from vaults or from the system as well.
     */
    function removeStrategy(address strategy, bool fromVaultsOnly) external;

    /**
     * @notice Syncs smart vault with strategies.
     * @param smartVault Smart vault to sync.
     * @param revertIfError If true, sync will revert if every flush index cannot be synced; if false it will sync all flush indexes it can.
     */
    function syncSmartVault(address smartVault, bool revertIfError) external;

    /**
     * @notice Instantly redeems smart vault shares for assets.
     * @param bag Parameters for fast redeemal.
     * @param withdrawalSlippages Slippages guarding redeemal.
     * @param exchangeRateSlippages Slippages used to constrain exchange rates for asset tokens.
     * @return withdrawnAssets Amount of assets withdrawn.
     */
    function redeemFast(
        RedeemBag calldata bag,
        uint256[][] calldata withdrawalSlippages,
        uint256[2][] calldata exchangeRateSlippages
    ) external returns (uint256[] memory withdrawnAssets);

    /**
     * @notice Claims withdrawal of assets by burning withdrawal NFT.
     * @dev Requirements:
     * - withdrawal NFT must be valid
     * @param smartVault Address of the smart vault that issued the withdrawal NFT.
     * @param nftIds ID of withdrawal NFT to burn.
     * @param nftAmounts amounts
     * @param receiver Receiver of claimed assets.
     * @return assetAmounts Amounts of assets claimed.
     * @return assetGroupId ID of the asset group.
     */
    function claimWithdrawal(
        address smartVault,
        uint256[] calldata nftIds,
        uint256[] calldata nftAmounts,
        address receiver
    ) external returns (uint256[] memory assetAmounts, uint256 assetGroupId);

    /**
     * @notice Claims smart vault tokens by burning the deposit NFT.
     * @dev Requirements:
     * - deposit NFT must be valid
     * - flush must be synced
     * @param smartVaultAddress Address of the smart vault that issued the deposit NFT.
     * @param nftIds ID of the deposit NFT to burn.
     * @param nftAmounts amounts
     * @return claimedAmount Amount of smart vault tokens claimed.
     */
    function claimSmartVaultTokens(address smartVaultAddress, uint256[] calldata nftIds, uint256[] calldata nftAmounts)
        external
        returns (uint256 claimedAmount);

    /**
     * @notice Initiates a withdrawal process and mints a withdrawal NFT. Once all DHWs are executed, user can
     * use the withdrawal NFT to claim the assets.
     * Optionally, caller can pass a list of deposit NFTs to unwrap.
     * @param bag smart vault address, amount of shares to redeem, nft ids and amounts to burn
     * @param receiver address that will receive the withdrawal NFT
     * @param doFlush optionally flush the smart vault
     * @return receipt ID of the receipt withdrawal NFT.
     */
    function redeem(RedeemBag calldata bag, address receiver, bool doFlush) external returns (uint256 receipt);

    /**
     * @notice Initiates a withdrawal process and mints a withdrawal NFT. Once all DHWs are executed, user can
     * use the withdrawal NFT to claim the assets.
     * Optionally, caller can pass a list of deposit NFTs to unwrap.
     * @param bag smart vault address, amount of shares to redeem, nft ids and amounts to burn
     * @param owner address that owns the shares to be redeemed and will receive the withdrawal NFT
     * @param doFlush optionally flush the smart vault
     * @return receipt ID of the receipt withdrawal NFT.
     */
    function redeemFor(RedeemBag calldata bag, address owner, bool doFlush) external returns (uint256 receipt);

    /**
     * @notice Initiated a deposit and mints a deposit NFT. Once all DHWs are executed, user can
     * unwrap the deposit NDF and claim his SVTs.
     * @param bag smartVault address, assets, NFT receiver address, referral address, doFlush
     * @return receipt ID of the receipt deposit NFT.
     */
    function deposit(DepositBag calldata bag) external returns (uint256 receipt);

    /* ========== EVENTS ========== */

    /**
     * @notice Smart vault has been flushed
     * @param smartVault Smart vault address
     * @param flushIndex Flush index
     */
    event SmartVaultFlushed(address indexed smartVault, uint256 flushIndex);

    /**
     * @notice Smart vault has been synced
     * @param smartVault Smart vault address
     * @param flushIndex Flush index
     */
    event SmartVaultSynced(address indexed smartVault, uint256 flushIndex);
}
