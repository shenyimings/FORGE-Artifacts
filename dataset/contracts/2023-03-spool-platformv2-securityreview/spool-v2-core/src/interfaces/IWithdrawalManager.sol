// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../libraries/uint16a16Lib.sol";

/**
 * @notice Base information for redeemal.
 * @custom:member smartVault Smart vault from which to redeem.
 * @custom:member shares Amount of smart vault shares to redeem.
 * @custom:member nftIds IDs of deposit NFTs to burn before redeemal.
 * @custom:member nftAmounts Amounts of NFT shares to burn.
 */
struct RedeemBag {
    address smartVault;
    uint256 shares;
    uint256[] nftIds;
    uint256[] nftAmounts;
}

/**
 * @notice Extra information for fast redeemal.
 * @custom:member strategies Strategies of the smart vault.
 * @custom:member assetGroup Asset group of the smart vault.
 * @custom:member assetGroupId ID of the asset group of the smart vault.
 * @custom:member redeemer Address that initiated the redeemal.
 * @custom:member withdrawalSlippages Slippages used to guard redeemal.
 * @custom:member exchangeRateSlippages Slippages used to constrain exchange rates for asset tokens.
 */
struct RedeemFastExtras {
    address[] strategies;
    address[] assetGroup;
    uint256 assetGroupId;
    address redeemer;
    uint256[][] withdrawalSlippages;
    uint256[2][] exchangeRateSlippages;
}

/**
 * @notice Extra information for redeemal.
 * @custom:member receiver Receiver of the withdraw NFT.
 * @custom:member redeemer Address that initiated the redeemal.
 * @custom:member flushIndex Current flush index of the smart vault.
 */
struct RedeemExtras {
    address receiver;
    address redeemer;
    uint256 flushIndex;
}

/**
 * @notice Information used to claim withdrawal.
 * @custom:member smartVault Smart vault from which to claim withdrawal.
 * @custom:member nftIds Withdrawal NFTs to burn while claiming withdrawal.
 * @custom:member nftAmounts Amounts of NFT shares to burn.
 * @custom:member receiver Receiver of withdrawn assets.
 * @custom:member executor Address that initiated the withdrawal claim.
 * @custom:member assetGroupId ID of the asset group of the smart vault.
 * @custom:member assetGroup Asset group of the smart vault.
 */
struct WithdrawalClaimBag {
    address smartVault;
    uint256[] nftIds;
    uint256[] nftAmounts;
    address receiver;
    address executor;
    uint256 assetGroupId;
    address[] assetGroup;
}

interface IWithdrawalManager {
    /**
     * @notice User redeemed withdrawal NFTs for underlying assets
     * @param smartVault Smart vault address
     * @param claimer Claimer address
     * @param nftIds NFTs to burn
     * @param nftAmounts NFT shares to burn
     * @param withdrawnAssets Amount of underlying assets withdrawn
     */
    event WithdrawalClaimed(
        address indexed smartVault,
        address indexed claimer,
        uint256 assetGroupId,
        uint256[] nftIds,
        uint256[] nftAmounts,
        uint256[] withdrawnAssets
    );

    /**
     * @notice A deposit has been initiated
     * @param smartVault Smart vault address
     * @param owner Owner of shares to be redeemed
     * @param redeemId Withdrawal NFT ID for this redeemal
     * @param flushIndex Flush index the redeem was scheduled for
     * @param shares Amount of vault shares to redeem
     * @param receiver Beneficiary that will be able to claim the underlying assets
     */
    event RedeemInitiated(
        address indexed smartVault,
        address indexed owner,
        uint256 indexed redeemId,
        uint256 flushIndex,
        uint256 shares,
        address receiver
    );

    /**
     * @notice A deposit has been initiated
     * @param smartVault Smart vault address
     * @param redeemer Redeem initiator and owner of shares
     * @param shares Amount of vault shares to redeem
     * @param nftIds NFTs to burn
     * @param nftAmounts NFT shares to burn
     * @param assetsWithdrawn Amount of underlying assets withdrawn
     */
    event FastRedeemInitiated(
        address indexed smartVault,
        address indexed redeemer,
        uint256 shares,
        uint256[] nftIds,
        uint256[] nftAmounts,
        uint256[] assetsWithdrawn
    );

    /**
     * @notice Flushes smart vaults deposits and withdrawals to the strategies.
     * @dev Requirements:
     *   - can only be called by user granted ROLE_SMART_VAULT_MANAGER
     * @param smartVault Smart vault to flush.
     * @param flushIndex Current flush index of the smart vault.
     * @param strategies Strategies of the smart vault.
     * @return dhwIndexes current do-hard-work indexes of the strategies.
     */
    function flushSmartVault(address smartVault, uint256 flushIndex, address[] calldata strategies)
        external
        returns (uint16a16 dhwIndexes);

    /**
     * @notice Claims withdrawal.
     * @dev Requirements:
     *   - can only be called by user granted ROLE_SMART_VAULT_MANAGER
     * @param bag Parameters for claiming withdrawal.
     * @return withdrawnAssets Amount of assets withdrawn.
     * @return assetGroupId ID of the asset group.
     */
    function claimWithdrawal(WithdrawalClaimBag calldata bag)
        external
        returns (uint256[] memory withdrawnAssets, uint256 assetGroupId);

    /**
     * @notice Syncs withdrawals between strategies and smart vault after do-hard-works.
     * @dev Requirements:
     *   - can only be called by user granted ROLE_SMART_VAULT_MANAGER
     * @param smartVault Smart vault to sync.
     * @param flushIndex Smart vault's flush index to sync.
     * @param strategies Strategies of the smart vault.
     * @param dhwIndexes_ Strategies' do-hard-work indexes to sync.
     */
    function syncWithdrawals(
        address smartVault,
        uint256 flushIndex,
        address[] calldata strategies,
        uint16a16 dhwIndexes_
    ) external;

    /**
     * @notice Redeems smart vault shares.
     * @dev Requirements:
     *   - can only be called by user granted ROLE_SMART_VAULT_MANAGER
     * @param bag Base information for redeemal.
     * @param bag2 Extra information for redeemal.
     * @return nftId ID of the withdrawal NFT.
     */
    function redeem(RedeemBag calldata bag, RedeemExtras calldata bag2) external returns (uint256 nftId);

    /**
     * @notice Instantly redeems smart vault shares.
     * @dev Requirements:
     *   - can only be called by user granted ROLE_SMART_VAULT_MANAGER
     * @param bag Base information for redeemal.
     * @param bag Extra information for fast redeemal.
     * @return assets Amount of assets withdrawn.
     */
    function redeemFast(RedeemBag calldata bag, RedeemFastExtras memory bag2)
        external
        returns (uint256[] memory assets);
}
