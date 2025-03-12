// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

// contracts
import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

// libraries
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TestERC4626 is ERC4626 {
    using Math for uint256;

    constructor(string memory name_, string memory symbol_, IERC20Metadata asset_)
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {}

    // overwrite initial mint function to force ERC4626 to have 18 decimals of precision for minting
    function decimals() public view virtual override(ERC4626) returns (uint8) {
        return 18;
    }

    function _initialConvertToShares(uint256 assets, Math.Rounding /*rounding*/ )
        internal
        view
        override
        returns (uint256 shares)
    {
        uint8 assetDecimals = IERC20Metadata(asset()).decimals();
        return assets * 10 ** (decimals() - assetDecimals);
    }

    function _initialConvertToAssets(uint256 shares, Math.Rounding /*rounding*/ )
        internal
        view
        override
        returns (uint256 assets)
    {
        uint8 assetDecimals = IERC20Metadata(asset()).decimals();
        return shares * 10 ** (decimals() - assetDecimals);
    }
}
