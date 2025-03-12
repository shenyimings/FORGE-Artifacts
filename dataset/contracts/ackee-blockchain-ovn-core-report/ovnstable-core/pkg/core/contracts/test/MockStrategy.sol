// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IStrategy.sol";


contract MockStrategy is IStrategy {

    IERC20 public asset;
    bool public navLess;

    // --- Setters

    constructor(address _asset, uint256 nonce)  {
        require(_asset != address(0), "Zero address not allowed");
        asset = IERC20(_asset);
    }

    function setNavLess(bool value) external {
        navLess = value;
    }

    // --- logic

    function stake(
        address _asset,
        uint256 _amount
    ) external override {
        return;
    }

    function unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary,
        bool targetIsZero
    ) external override returns (uint256) {
        uint256 balance = asset.balanceOf(address(this));
        if (targetIsZero) {
            asset.transfer(_beneficiary, balance);
            return balance;
        } else {
            require(balance >= _amount, "MockStrategy: unstake more than balance");
            asset.transfer(_beneficiary, _amount);

            if(navLess){
                asset.transfer(_beneficiary, asset.balanceOf(address(this)));
            }

            return _amount;
        }
    }


    function netAssetValue() external view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function liquidationValue() external view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function claimRewards(address _to) external override returns (uint256) {
        return 0;
    }

}
