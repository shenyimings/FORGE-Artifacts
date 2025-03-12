// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

/**
 * @notice Used when number of provided APYs or risk scores does not match number of provided strategies.
 */
error ApysOrRiskScoresLengthMismatch(uint256, uint256);

/**
 * @notice Input for calculating allocation.
 * @custom:member strategies Strategies to allocate.
 * @custom:member apys APYs for each strategy.
 * @custom:member riskScores Risk scores for each strategy.
 * @custom:member riskTolerance Risk tolerance of the smart vault.
 */
struct AllocationCalculationInput {
    address[] strategies;
    int256[] apys;
    uint8[] riskScores;
    int8 riskTolerance;
}

interface IAllocationProvider {
    /**
     * @notice Calculates allocation between strategies based on input parameters.
     * @param data Input data for allocation calculation.
     * @return allocation Calculated allocation.
     */
    function calculateAllocation(AllocationCalculationInput calldata data)
        external
        view
        returns (uint256[] memory allocation);
}
