// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract MockProtocolDHedge is ERC4626 {
    using Math for uint256;

    constructor(address asset_) ERC4626(ERC20(asset_)) ERC20("MockProtocolDHedge", "MOCKPROTOCOLDHEDGE") {}

    /// @notice Deposit funds into the pool
    /// @dev https://github.com/dhedge/V2-Public/blob/ba2f06d40a87e18a150f4055def5e7a2d596c719/contracts/PoolLogic.sol#L275
    /// asset_ Address of the token
    /// @param amount_ Amount of tokens to deposit
    /// @return liquidityMinted Amount of liquidity minted
    function depositFor(address recipient_, address, uint256 amount_) external returns (uint256 liquidityMinted) {
        uint256 shares_ = _convertToShares(amount_, Math.Rounding.Down);
        _deposit(_msgSender(), recipient_, amount_, shares_);
        liquidityMinted = shares_;
    }

    /// @notice Withdraw assets based on the fund token amount
    /// @dev https://github.com/dhedge/V2-Public/blob/ba2f06d40a87e18a150f4055def5e7a2d596c719/contracts/PoolLogic.sol#L364
    /// @param recipient_ the receipient
    /// @param fundTokenAmount_ the fund token amount
    function withdrawTo(address recipient_, uint256 fundTokenAmount_) external {
        uint256 assetAmount_ = _convertToAssets(fundTokenAmount_, Math.Rounding.Down);
        _withdraw(_msgSender(), recipient_, _msgSender(), assetAmount_, fundTokenAmount_);
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     * @dev To mock non 1:1 share price
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual override returns (uint256) {
        return assets.mulDiv(1100, 1000, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     * @dev To mock non 1:1 share price
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual override returns (uint256) {
        return shares.mulDiv(1000, 1100, rounding);
    }
}
