// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { TokenAmount } from "./CommonTypes.sol";

/*
 *  @title IVault
 *
 *  @notice The standard interface for a generic vault as described by the "Vault Framework".
 *          http://thinking.farm/essays/2022-10-05-mechanical-finance/
 *
 *          Users deposit a "underlying" asset and mint "notes" (or vault shares).
 *          The vault "deploys" underlying asset in a rules-based fashion (through a hard-coded strategy).
 *          It "recovers" deployed assets once the investment matures.
 *
 *          The vault operates through two external poke functions which off-chain keepers can execute.
 *              1) `deploy`: When executed, the vault "puts to work" the underlying assets it holds. The vault
 *                           usually returns other ERC-20 tokens which act as receipts of the deployment.
 *              2) `recover`: When executed, the vault turns in the receipts and retrieves the underlying asset and
 *                            usually collects some yield for this work.
 *
 *          The rules of the deployment and recovery are specific to the vault strategy.
 *
 *          At any time the vault will hold multiple ERC20 tokens, together referred to as the vault's "assets".
 *          They can be a combination of the underlying asset and the deployed assets (receipts).
 *
 *          On redemption users burn their "notes" to receive a proportional slice of all the vault's assets.
 *
 */

interface IVault is IERC20Upgradeable {
    /// @notice Recovers deployed funds and redeploys them.
    function recoverAndRedeploy() external;

    /// @notice Deploys deposited funds.
    function deploy() external;

    /// @notice Recovers deployed funds.
    function recover() external;

    /// @notice Recovers a given deployed asset.
    /// @param token The ERC-20 token address of the deployed asset.
    function recover(IERC20Upgradeable token) external;

    /// @notice Deposits the underlying asset from {msg.sender} into the vault and mints notes.
    /// @param amount The amount tokens to be deposited into the vault.
    /// @return The amount of notes.
    function deposit(uint256 amount) external returns (uint256);

    /// @notice Burns notes and sends a proportional share of vault's assets back to {msg.sender}.
    /// @param notes The amount of notes to be burnt.
    /// @return The list of asset tokens and amounts redeemed.
    function redeem(uint256 notes) external returns (TokenAmount[] memory);

    /// @notice Batches the recover and redeem functions.
    /// @param notes The amount of notes to be burnt.
    /// @return The list of asset tokens and amounts redeemed.
    function recoverAndRedeem(uint256 notes) external returns (TokenAmount[] memory);

    /// @return The total value of assets currently held by the vault, denominated in a standard unit of account.
    function getTVL() external view returns (uint256);

    /// @param token The address of the asset ERC-20 token held by the vault.
    /// @return The vault's asset token value, denominated in a standard unit of account.
    function getVaultAssetValue(IERC20Upgradeable token) external view returns (uint256);

    /// @notice The ERC20 token that can be deposited into this vault.
    function underlying() external view returns (IERC20Upgradeable);

    /// @return Total count of ERC-20 tokens held by the vault.
    function assetCount() external view returns (uint256);

    /// @param i The index of a token.
    /// @return The vault's asset token address by index.
    function assetAt(uint256 i) external view returns (IERC20Upgradeable);

    /// @param token The address of the asset ERC-20 token held by the vault.
    /// @return The vault's asset token balance.
    function vaultAssetBalance(IERC20Upgradeable token) external view returns (uint256);

    /// @param token The address of a token to check.
    /// @return If the given token is held by the vault.
    function isVaultAsset(IERC20Upgradeable token) external view returns (bool);

    /// @notice Computes the amount of notes minted when given amount of underlying asset tokens
    ///         are deposited into the system.
    /// @param amount The amount tokens to be deposited into the vault.
    /// @return The amount of notes to be minted.
    function computeMintAmt(uint256 amount) external returns (uint256);

    /// @notice Computes the amount of asset tokens redeemed when burning given number of vault notes.
    /// @param notes The amount of notes to be burnt.
    /// @return The list of asset tokens and amounts redeemed.
    function computeRedemptionAmts(uint256 notes) external returns (TokenAmount[] memory);
}
