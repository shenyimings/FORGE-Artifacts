// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IEmissionSchedule {
    function getReceiverWeeklyEmissions(uint id, uint week, uint totalWeeklyEmissions) external returns (uint);

    function getTotalWeeklyEmissions(uint week, uint unallocatedTotal) external returns (uint amount, uint lockWeeks);

    function notifyReducedSupply(uint amount) external returns (bool);
}
