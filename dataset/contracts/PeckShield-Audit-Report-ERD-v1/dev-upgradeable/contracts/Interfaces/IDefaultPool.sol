// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./IPool.sol";

interface IDefaultPool is IPool {
    // --- Events ---
    event DefaultPoolEUSDDebtUpdated(uint256 _EUSDDebt);
    event DefaultPoolCollBalanceUpdated(
        address _collateral,
        uint256 _coll,
        uint256 _totalColl
    );
    event DefaultPoolCollBalanceUpdated(address[] _collaterals, uint256[] _collAmounts);

    // --- Functions ---
    function sendCollateralToActivePool(
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) external;

    function increaseEUSDDebt(uint256 _amount) external;

    function decreaseEUSDDebt(uint256 _amount) external;

    function getEUSDDebt() external view returns (uint256);
}
