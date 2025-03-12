// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./IPool.sol";

interface ICollSurplusPool is IPool {
    // --- Events ---

    event CollBalanceUpdated(address indexed _account, bool _hasBalance);
    event CollBalanceUpdated(address _collateral, uint256 _amount);

    // --- Contract setters ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _troveManagerLiquidationsAddress,
        address _troveManagerRedemptionsAddress,
        address _activePoolAddress,
        address _wethAddress
    ) external;

    function getCollateral(address _account, address _collateral)
        external
        view
        returns (uint256);

    function accountSurplus(address _account, uint256[] memory _amount)
        external;

    function claimColl(address _account) external;
}
