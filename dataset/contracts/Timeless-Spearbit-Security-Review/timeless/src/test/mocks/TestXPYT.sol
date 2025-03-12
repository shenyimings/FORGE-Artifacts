// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {IxPYT} from "../../external/IxPYT.sol";

contract TestXPYT is IxPYT {
    uint256 public assetBalance;

    constructor(ERC20 asset_) ERC4626(asset_, "TestXPYT", "TEST-XPYT") {}

    function sweep(address receiver)
        external
        virtual
        override
        returns (uint256 shares)
    {
        uint256 assets = asset.balanceOf(address(this)) - assetBalance;

        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function totalAssets() public view virtual override returns (uint256) {
        return assetBalance;
    }

    function beforeWithdraw(
        uint256 assets,
        uint256 /*shares*/
    ) internal virtual override {
        unchecked {
            assetBalance -= assets;
        }
    }

    function afterDeposit(
        uint256 assets,
        uint256 /*shares*/
    ) internal virtual override {
        assetBalance += assets;
    }
}
