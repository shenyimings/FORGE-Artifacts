// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITroveInterestRateStrategy {
    function getBaseBorrowRate() external view returns (uint256);

    function getMaxBorrowRate() external view returns (uint256);

    function calculateInterestRates() external view returns (uint256, uint256);
}
