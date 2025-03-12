// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../interfaces/IAllocationProvider.sol";
import "../interfaces/IRiskManager.sol";
import "../interfaces/Constants.sol";

contract UniformAllocationProvider is IAllocationProvider {
    function calculateAllocation(AllocationCalculationInput calldata data) external pure returns (uint256[] memory) {
        uint256[] memory allocations = new uint256[](data.strategies.length);
        uint256 allocation = FULL_PERCENT / data.strategies.length;
        for (uint8 i; i < data.strategies.length; ++i) {
            allocations[i] = allocation;
        }

        allocations[0] += (FULL_PERCENT - allocation * data.strategies.length);
        return allocations;
    }
}
