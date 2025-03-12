// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./RevenueShareVault.sol";
import "./interfaces/IYieldSourceRibbonEarn.sol";

contract RevenueShareVaultRibbonEarn is RevenueShareVault {
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
     * @dev to be used for calculating the revenue share ratio
     * @return yieldSourceTotalShares total yield source shares supply
     */
    function getYieldSourceVaultTotalShares() external view override returns (uint256) {
        return IYieldSourceRibbonEarn(yieldSourceVault).totalSupply();
    }

    /**
     * @dev Since this vault does not have direct control over the Ribbon Earn vault's withdrawal, using this function to provide an accurate calculation of totalSharesInReferral if needed
     * @dev This is fesiable as this vault is targeted for institutional users, and the number of users is expected to be small
     * @dev onlyOwner
     */
    function setTotalSharesInReferralAccordingToYieldSource(address referral, address user) external onlyOwner {
        require(referral != address(0) && user != address(0), "ZERO_ADDRESS");

        uint256 recordedUserShares_ = totalSharesByUserReferral[user][referral];
        uint256 updatedUserShares_ = shareBalanceAtYieldSourceOf(user);

        if (recordedUserShares_ > updatedUserShares_) {
            uint256 deltaShares_ = recordedUserShares_ - updatedUserShares_;
            _trackSharesInReferralRemoved(referral, user, deltaShares_);
            emit TotalSharesByUserReferralUpdated(user, referral, updatedUserShares_);
        } else if (recordedUserShares_ < updatedUserShares_) {
            uint256 deltaShares_ = updatedUserShares_ - recordedUserShares_;
            _trackSharesInReferralAdded(referral, user, deltaShares_);
            emit TotalSharesByUserReferralUpdated(user, referral, updatedUserShares_);
        }
    }

    /**
     * @param account target account address
     * @return shares yield source share balance of this vault
     */
    function shareBalanceAtYieldSourceOf(address account) public view override returns (uint256) {
        return IYieldSourceRibbonEarn(yieldSourceVault).shares(account);
    }

    /**
     * @dev Deposit assets to yield source vault
     * @dev virtual, expected to be overridden with specific yield source vault
     * @param asset_ The address of the ERC20 asset contract
     * @param amount_ The amount of assets to deposit
     * @return shares amount of shares received
     */
    function _depositToYieldSourceVault(address asset_, uint256 amount_) internal override returns (uint256) {
        IERC20(asset_).safeIncreaseAllowance(yieldSourceVault, amount_);
        uint256 sharesBalanceBefore = IYieldSourceRibbonEarn(yieldSourceVault).shares(_msgSender());
        IYieldSourceRibbonEarn(yieldSourceVault).depositFor(amount_, _msgSender());
        uint256 sharesBalanceAfter = IYieldSourceRibbonEarn(yieldSourceVault).shares(_msgSender());
        return sharesBalanceAfter - sharesBalanceBefore;
    }

    /**
     * @dev Redeem assets with vault shares from yield source vault
     * @dev For this integration, because of Ribbon Earn's multiple steps withdrawal (with time delay) mechanism, this contract will not be processing the yield source's withdrawal directly, but only for burning the intenal shares for tracking the revenue share.
     * @dev not supported
     * param shares amount of shares to burn and redeem assets
     * @return assets amount of assets received
     */
    function _redeemFromYieldSourceVault(uint256) internal pure override returns (uint256) {
        require(false, "RevenueShareVaultRibbonEarn: not supported");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[20] private __gap;
}
