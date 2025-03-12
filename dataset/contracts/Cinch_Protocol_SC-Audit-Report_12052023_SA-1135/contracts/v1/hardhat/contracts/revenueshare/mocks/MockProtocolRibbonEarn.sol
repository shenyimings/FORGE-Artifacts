// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IERC20Extended.sol";

contract MockProtocolRibbonEarn is ERC4626 {
    using Math for uint256;

    constructor(address asset_) ERC4626(ERC20(asset_)) ERC20("MockProtocolRibbonEarn", "MOCKPROTOCOLRIBBONEARN") {}

    /**
     * @notice Deposits the `asset` from msg.sender added to `creditor`'s deposit.
     * @notice Used for vault -> vault deposits on the user's behalf
     * @dev https://github.com/ribbon-finance/ribbon-v2/blob/7d8deadf8dd63273aeee105beebcb99564ad4711/contracts/vaults/RETHVault/base/RibbonVault.sol#L348
     * @param amount is the amount of `asset` to deposit
     * @param creditor is the address that can claim/withdraw deposited amount
     */
    function depositFor(uint256 amount, address creditor) external {
        uint256 shares_ = _convertToShares(amount, Math.Rounding.Down);
        _deposit(_msgSender(), creditor, amount, shares_);
    }

    /**
     * @notice Getter for returning the account's share balance including unredeemed shares
     * @param account is the account to lookup share balance for
     * @return the share balance
     */
    function shares(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     * @dev To mock non 1:1 share price
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal pure override returns (uint256) {
        return assets.mulDiv(1100, 1000, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     * @dev To mock non 1:1 share price
     */
    function _convertToAssets(uint256 shares_, Math.Rounding rounding) internal pure override returns (uint256) {
        return shares_.mulDiv(1000, 1100, rounding);
    }
}
