// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

contract TestERC4626 is ERC4626 {
    constructor(ERC20 asset_) ERC4626(asset_, "TestERC4626", "TEST-ERC4626") {}

    function totalAssets() public view virtual override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
