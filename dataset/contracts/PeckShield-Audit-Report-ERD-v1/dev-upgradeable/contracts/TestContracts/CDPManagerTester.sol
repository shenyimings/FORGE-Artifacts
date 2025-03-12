// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../TroveManager.sol";

/* Tester contract inherits from TroveManager, and provides external functions 
for testing the parent's internal functions. */

contract TroveManagerTester is TroveManager {
    function unprotectedDecayBaseRateFromBorrowing()
        external
        returns (uint256)
    {
        baseRate = calcDecayedBaseRate();
        require(
            baseRate >= 0 && baseRate <= DECIMAL_PRECISION,
            "unprotectedDecayBaseRateFromBorrowing: bad baseRate"
        );

        _updateLastFeeOpTime();
        return baseRate;
    }

    // function minutesPassedSinceLastFeeOp() external view returns (uint256) {
    //     return _minutesPassedSinceLastFeeOp();
    // }

    function setLastFeeOpTimeToNow() external {
        lastFeeOperationTime = block.timestamp;
    }

    function setBaseRate(uint256 _baseRate) external {
        baseRate = _baseRate;
    }
}
