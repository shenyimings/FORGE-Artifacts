// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.3 <=0.8.0;

import {SignedSafeMath} from "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import {Math} from "./Math.sol";

/**
 * @title Welford Algorithm
 * REFERENCE
 * https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Welford's_online_algorithm
 * This implementation of this algorithm was created by Ribbon Finance
 * https://github.com/ribbon-finance/rvol/blob/master/contracts/libraries/Welford.sol
 * @author SirenMarkets
 * @dev Contract to compute a dynamic volatilty of prices without needing to loop over them for each iteration of price calculations
 */

library Welford {
    using SignedSafeMath for int256;

    /**
     * @notice Performs an update of the mean and stdev using online algorithm
     * @param curCount is the current value for count
     * @param oldValue is the old value to be removed from the dataset
     * @param newValue is the new value to be added into the dataset
     * @param curMean is the current value for mean
     * @param curDSQ is the current value for DSQ
     */
    function update(
        uint256 curCount,
        int256 oldValue,
        int256 newValue,
        int256 curMean,
        int256 curDSQ
    ) internal pure returns (int256 mean, int256 dsq) {
        // Source
        //https://nestedsoftware.com/2019/09/26/incremental-average-and
        //-standard-deviation-with-sliding-window-470k.176143.html
        if (curCount == 1 && oldValue == 0) {
            // initialize when the first value is added
            mean = newValue;
        } else if (oldValue == 0) {
            // if the buffer is not full yet, use standard Welford method
            int256 meanIncrement = (newValue.sub(curMean)).div(
                int256(curCount)
            );
            mean = curMean.add(meanIncrement);
            dsq = curDSQ.add((newValue.sub(mean)).mul(newValue.sub(curMean)));
        } else {
            // once the buffer is full, adjust Welford Method for window size
            int256 meanIncrement = newValue.sub(oldValue).div(int256(curCount));
            mean = curMean.add(meanIncrement);
            dsq = curDSQ.add(
                (newValue.sub(oldValue)).mul(
                    newValue.add(oldValue).sub(mean).sub(curMean)
                )
            );
        }

        require(dsq >= 0, "dsq<0");
    }

    /**
     * @notice Calculate the variance using the existing tuple (count, mean, m2)
     * @param count is the length of the dataset
     * @param dsq is the variance * count
     */
    function sampleVariance(uint256 count, int256 dsq)
        internal
        pure
        returns (uint256)
    {
        require(count > 0, "!count");
        require(dsq >= 0, "!dsq");
        return uint256(dsq) / count;
    }

    /**
     * @notice Calculate the standard deviation using the existing tuple (count, mean, m2)
     * @param count is the length of the dataset
     * @param dsq is the variance * count
     */
    function stdev(uint256 count, int256 dsq) internal pure returns (uint256) {
        return Math.sqrt(sampleVariance(count, dsq));
    }
}
