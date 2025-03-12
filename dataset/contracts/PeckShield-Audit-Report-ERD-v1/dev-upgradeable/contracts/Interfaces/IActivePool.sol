// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./IPool.sol";

interface IActivePool is IPool {
    // --- Events ---
    event ActivePoolEUSDDebtUpdated(uint256 _EUSDDebt);
    event ActivePoolCollBalanceUpdated(
        address _collateral,
        uint256 _amount
    );

    // --- Functions ---
    function sendCollateral(
        address _account,
        address[] memory _collaterals,
        uint256[] memory _colls
    ) external;

    function sendCollFees(
        address[] memory _collaterals,
        uint256[] memory _colls
    ) external;

    function increaseEUSDDebt(uint256 _amount) external;

    function decreaseEUSDDebt(uint256 _amount) external;

    function getEUSDDebt() external view returns (uint256);
}
