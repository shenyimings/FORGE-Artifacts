// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IERC20Extended.sol";

contract MockProtocol is ERC4626 {
    using Math for uint256;

    constructor(address asset_) ERC4626(ERC20(asset_)) ERC20("MockProtocol", "MOCKPROTOCOL") {}

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
