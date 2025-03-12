// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../libraries/ScaledMath.sol";
import "../interfaces/pools/IConicPool.sol";

library PoolHelpers {
    using ScaledMath for uint256;

    function computeDeviationRatio(IConicPool pool) external view returns (uint256) {
        uint256 allocatedUnderlying_ = pool.totalUnderlying();
        if (allocatedUnderlying_ == 0) return 0;
        uint256 deviation = pool.computeTotalDeviation();
        return deviation.divDown(allocatedUnderlying_);
    }
}
