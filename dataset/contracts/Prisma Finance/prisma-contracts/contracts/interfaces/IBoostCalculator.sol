// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IBoostCalculator {
    function getBoostedAmount(
        address account,
        uint amount,
        uint previousAmount,
        uint totalWeeklyEmissions
    ) external view returns (uint adjustedAmount);

    function getBoostedAmountWrite(
        address account,
        uint amount,
        uint previousAmount,
        uint totalWeeklyEmissions
    ) external returns (uint adjustedAmount);

    function getClaimableWithBoost(
        address claimant,
        uint previousAmount,
        uint totalWeeklyEmissions
    ) external view returns (uint, uint);
}
