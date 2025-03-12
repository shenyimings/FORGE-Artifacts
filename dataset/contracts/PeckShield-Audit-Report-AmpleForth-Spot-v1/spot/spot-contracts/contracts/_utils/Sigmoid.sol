// SPDX-License-Identifier: GPL-3.0-or-later
// https://github.com/ampleforth/ampleforth-contracts/blob/master/contracts/UFragmentsPolicy.sol
pragma solidity ^0.8.20;

import { SignedMathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SignedMathUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

/// @notice Expected exponent to be at most 100.
error ExpTooLarge();

/**
 *  @title Sigmoid
 *
 *  @notice Library with helper functions to compute y = sigmoid(x).
 *
 */
library Sigmoid {
    using SignedMathUpgradeable for int256;
    using SafeCastUpgradeable for uint256;

    /// @notice Computes 2^exp with limited precision where -100 <= exp <= 100 * one
    /// @param exp The power to raise 2 to -100 <= exp <= 100 * one
    /// @param one 1.0 represented in the same fixed point number format as exp
    /// @return 2^exp represented with same number of decimals after the point as one
    function twoPower(int256 exp, int256 one) internal pure returns (int256) {
        bool reciprocal = false;
        if (exp < 0) {
            reciprocal = true;
            exp = exp.abs().toInt256();
        }

        // Precomputed values for 2^(1/2^i) in 18 decimals fixed point numbers
        int256[5] memory ks = [
            int256(1414213562373095049),
            1189207115002721067,
            1090507732665257659,
            1044273782427413840,
            1021897148654116678
        ];
        int256 whole = exp / one;
        if (whole > 100) {
            revert ExpTooLarge();
        }
        int256 result = int256(uint256(1) << uint256(whole)) * one;
        int256 remaining = exp - (whole * one);

        int256 current = one / 2;
        for (uint256 i = 0; i < 5; ++i) {
            if (remaining >= current) {
                remaining = remaining - current;
                result = (result * ks[i]) / 10 ** 18; // 10**18 to match hardcoded ks values
            }
            current = current / 2;
        }
        if (reciprocal) {
            result = (one * one) / result;
        }
        return result;
    }

    /// @notice Given number x and sigmoid parameters all represented as fixed-point number with
    ///         the same number of decimals, it computes y = sigmoid(x).
    /// @param x The sigmoid function input value.
    /// @param lower The lower asymptote.
    /// @param upper The upper asymptote.
    /// @param growth The growth parameter.
    /// @param one 1.0 as a fixed-point.
    /// @return The computed value of sigmoid(x) as fixed-point number.
    function compute(int256 x, int256 lower, int256 upper, int256 growth, int256 one) internal pure returns (int256) {
        int256 delta;

        delta = x - one;

        // Compute: (Upper-Lower)/(1-(Upper/Lower)/2^(Growth*delta))) + Lower

        int256 exponent = (growth * delta) / one;

        // Cap exponent to guarantee it is not too big for twoPower
        if (exponent > one * 100) {
            exponent = one * 100;
        }
        if (exponent < one * -100) {
            exponent = one * -100;
        }

        int256 pow = twoPower(exponent, one); // 2^(Growth*Delta)
        if (pow == 0) {
            return lower;
        }
        int256 numerator = upper - lower; //(Upper-Lower)
        int256 intermediate = (upper * one) / lower;
        intermediate = (intermediate * one) / pow;
        int256 denominator = one - intermediate; // (1-(Upper/Lower)/2^(Growth*delta)))

        int256 y = ((numerator * one) / denominator) + lower;
        return y;
    }
}
