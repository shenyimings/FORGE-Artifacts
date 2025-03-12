// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../RevenueShareVault.sol";
import "../interfaces/IYieldSourceContract.sol";

contract MockRevenueShareVault is RevenueShareVault {
    using SafeERC20 for IERC20;

    /**
     * @notice vault initializer
     * @param asset_ underneath asset, which should match the asset of the yield source vault
     * @param name_ ERC20 name of the vault shares token
     * @param symbol_ ERC20 symbol of the vault shares token
     * @param yieldSourceVault_ vault address of yield source
     * @param cinchPerformanceFeePercentage_ Cinch performance fee percentage with 2 decimals
     */
    function initialize(address asset_, string calldata name_, string calldata symbol_, address yieldSourceVault_, uint256 cinchPerformanceFeePercentage_) public initializer {
        __RevenueShareVault_init(asset_, name_, symbol_, yieldSourceVault_, cinchPerformanceFeePercentage_);
    }

    /**
     * @dev for testing the onlyInitializing modifier of __RevenueShareVault_init
     */
    function nonInitialize(address asset_, string calldata name_, string calldata symbol_, address yieldSourceVault_, uint256 cinchPerformanceFeePercentage_) external {
        __RevenueShareVault_init(asset_, name_, symbol_, yieldSourceVault_, cinchPerformanceFeePercentage_);
    }

    /**
     * @dev for testing the onlyInitializing modifier of __RevenueShareVault_init_unchained
     */
    function nonInitializeUnchained(address asset_, string calldata name_, string calldata symbol_, address yieldSourceVault_, uint256 cinchPerformanceFeePercentage_) external {
        __RevenueShareVault_init_unchained(asset_, name_, symbol_, yieldSourceVault_, cinchPerformanceFeePercentage_);
    }

    /**
     * @dev to be used for calculating the revenue share ratio
     * @return yieldSourceTotalShares total yield source shares supply
     */
    function getYieldSourceVaultTotalShares() external view virtual override returns (uint256) {
        return IYieldSourceContract(yieldSourceVault).totalSupply();
    }

    /**
     * @param account target account address
     * @return shares yield source share balance of this vault
     */
    function shareBalanceAtYieldSourceOf(address account) public view virtual override returns (uint256) {
        return IYieldSourceContract(yieldSourceVault).balanceOf(account);
    }

    /**
     * @dev Deposit assets to yield source vault
     * @dev virtual, expected to be overridden with specific yield source vault
     * @param asset_ The address of the ERC20 asset contract
     * @param amount_ The amount of assets to deposit
     * @return shares amount of shares received
     */
    function _depositToYieldSourceVault(address asset_, uint256 amount_) internal virtual override returns (uint256) {
        IERC20(asset_).safeIncreaseAllowance(yieldSourceVault, amount_);
        return IYieldSourceContract(yieldSourceVault).deposit(amount_, address(this));
    }

    /**
     * @dev Redeem assets with vault shares from yield source vault
     * @dev virtual, expected to be overridden with specific yield source vault
     * @param shares amount of shares to burn and redeem assets
     * @return assets amount of assets received
     */
    function _redeemFromYieldSourceVault(uint256 shares) internal virtual override returns (uint256) {
        return IYieldSourceContract(yieldSourceVault).redeem(shares, address(this), address(this));
    }
}
