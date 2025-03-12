 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0.0;

import { IVestingFlex } from  "../vesting/interfaces/IVestingFlex.sol";

import "solmate/src/mixins/ERC4626.sol";


contract VaultStaking is ERC4626(ERC20(address(0)), "","") {

    IVestingFlex public immutable vesting = IVestingFlex(address(0));
    uint256 public vestingDefault = 0;

    uint256[] private slots = [0];
    function totalAssets() public view override returns(uint256) {
        return asset.balanceOf(address(this));
    }

    function beforeDeposit() internal override {
        inject(vestingDefault);
    }

    function inject(uint256 slot) public {vesting.retrieve(slot);}
}