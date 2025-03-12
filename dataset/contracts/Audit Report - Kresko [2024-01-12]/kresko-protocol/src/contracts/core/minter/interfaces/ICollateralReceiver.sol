// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ICollateralReceiver {
    function onUncheckedCollateralWithdraw(
        address _account,
        address _collateralAsset,
        uint256 _withdrawalAmount,
        uint256 _depositedCollateralAssetIndex,
        bytes memory _userData
    ) external returns (bytes memory);
}
