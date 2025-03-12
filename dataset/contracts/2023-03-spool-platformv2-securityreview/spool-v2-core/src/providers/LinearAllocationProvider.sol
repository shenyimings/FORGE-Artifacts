// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../interfaces/IAllocationProvider.sol";
import "../interfaces/IRiskManager.sol";
import "../interfaces/Constants.sol";

contract AllocationProviderLinear is IAllocationProvider {
    function calculateAllocation(AllocationCalculationInput calldata data) external pure returns (uint256[] memory) {
        uint256 resSum = 0;
        uint256 apySum = 0;
        uint256 riskSum = 0;
        uint256[] memory results = new uint256[](data.apys.length);

        uint24[21] memory riskArray = [
            100000,
            95000,
            900000,
            85000,
            80000,
            75000,
            70000,
            65000,
            60000,
            55000,
            50000,
            45000,
            40000,
            35000,
            30000,
            25000,
            20000,
            15000,
            10000,
            5000,
            0
        ];

        uint8[] memory arrayRiskScores = data.riskScores;
        for (uint8 i; i < data.apys.length; ++i) {
            apySum += (data.apys[i] > 0 ? uint256(data.apys[i]) : 0);
            riskSum += arrayRiskScores[i];
        }

        uint8 riskt = uint8(data.riskTolerance + 10); // from 0 to 20

        for (uint8 i; i < data.apys.length; ++i) {
            uint256 apy = data.apys[i] > 0 ? uint256(data.apys[i]) : 0;
            apy = (apy * FULL_PERCENT) / apySum;
            uint256 risk =
                (FULL_PERCENT - (arrayRiskScores[i] * FULL_PERCENT) / riskSum) / (uint256(data.apys.length) - 1);

            results[i] = apy * riskArray[uint8(20 - riskt)] + risk * riskArray[uint8(riskt)];

            resSum += results[i];
        }

        uint256 resSum2;
        for (uint8 i; i < results.length; ++i) {
            results[i] = FULL_PERCENT * results[i] / resSum;
            resSum2 += results[i];
        }

        results[0] += FULL_PERCENT - resSum2;

        return results;
    }
}
