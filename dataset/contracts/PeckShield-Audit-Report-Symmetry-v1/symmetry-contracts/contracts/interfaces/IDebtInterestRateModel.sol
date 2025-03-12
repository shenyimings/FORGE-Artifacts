// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IDebtInterestRateModel {
    function updateMaxInterestRate() external;

    function nextInterest() external view returns (int);

    function update(int _totalDebt, int _debtRatio) external;
}
