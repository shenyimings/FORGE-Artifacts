// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title GeneralYieldSourceAdapter
 * @dev sub-contract of Revenue Share Vault, serving as the Yield Source Adapter template
 */
abstract contract GeneralYieldSourceAdapter is Initializable {
    /// @dev Yield source vault address
    address public yieldSourceVault;

    /// @dev Emitted when the yieldSourceVault address is updated.
    event YieldSourceVaultUpdated(address yieldSourceVault_);

    /**
     * @dev to be used for calculating the revenue share ratio
     * @dev virtual, expected to be overridden with specific yield source vault
     * @return yieldSourceTotalShares total yield source shares supply
     */
    function getYieldSourceVaultTotalShares() external view virtual returns (uint256);

    /**
     * @param account target account address
     * @dev virtual, expected to be overridden with specific yield source vault
     * @return shares yield source share balance of this vault
     */
    function shareBalanceAtYieldSourceOf(address account) public view virtual returns (uint256);

    /**
     * @notice GeneralYieldSourceAdapter initializer
     * @param yieldSourceVault_ vault address of yield source
     */
    function __GeneralYieldSourceAdapter_init(address yieldSourceVault_) internal onlyInitializing {
        __GeneralYieldSourceAdapter_init_unchained(yieldSourceVault_);
    }

    function __GeneralYieldSourceAdapter_init_unchained(address yieldSourceVault_) internal onlyInitializing {
        yieldSourceVault = yieldSourceVault_;
        emit YieldSourceVaultUpdated(yieldSourceVault_);
    }

    /**
     * @dev Deposit assets to yield source vault
     * @dev virtual, expected to be overridden with specific yield source vault
     * @param asset_ The address of the ERC20 asset contract
     * @param amount_ The amount of assets to deposit
     * @return shares amount of shares received
     */
    function _depositToYieldSourceVault(address asset_, uint256 amount_) internal virtual returns (uint256);

    /**
     * @dev Redeem assets with vault shares from yield source vault
     * @dev virtual, expected to be overridden with specific yield source vault
     * @param shares amount of shares to burn and redeem assets
     * @return assets amount of assets received
     */
    function _redeemFromYieldSourceVault(uint256 shares) internal virtual returns (uint256);

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[19] private __gap;
}
