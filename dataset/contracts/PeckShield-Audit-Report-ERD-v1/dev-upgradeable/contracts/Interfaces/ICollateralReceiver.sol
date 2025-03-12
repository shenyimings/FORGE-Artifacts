// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface ICollateralReceiver {
    function receiveCollateral(
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) external;
}
