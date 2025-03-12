// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ScaledMath.sol";

library SquareRoot {
    using ScaledMath for uint256;
    using ScaledMath for int256;

    enum Precision {
        None,
        Low,
        High
    }

    uint256 private constant SQRT_1E_NEG_1 = 316227766016837933;
    uint256 private constant SQRT_1E_NEG_3 = 31622776601683793;
    uint256 private constant SQRT_1E_NEG_5 = 3162277660168379;
    uint256 private constant SQRT_1E_NEG_7 = 316227766016837;
    uint256 private constant SQRT_1E_NEG_9 = 31622776601683;
    uint256 private constant SQRT_1E_NEG_11 = 3162277660168;
    uint256 private constant SQRT_1E_NEG_13 = 316227766016;
    uint256 private constant SQRT_1E_NEG_15 = 31622776601;
    uint256 private constant SQRT_1E_NEG_17 = 316227766;

    uint256 private constant MIN_STEP_SIZE = 5;

    uint256 private constant ONE_PREC_NONE = 10 ** 0;
    uint256 private constant ONE_PREC_6 = 10 ** 6;
    uint256 private constant ONE_PREC_18 = 10 ** 18;

    /** @dev Implements square root algorithm using Newton's method and a first-guess optimisation **/
    function sqrt(int256 input, uint256 threshold) internal pure returns (uint256) {
        return sqrt(uint256(input), threshold, Precision.High);
    }

    /** @dev Implements square root algorithm using Newton's method and a first-guess optimisation **/
    function sqrt(uint256 input, uint256 threshold) internal pure returns (uint256) {
        return sqrt(uint256(input), threshold, Precision.High);
    }

    function sqrt(
        uint256 input,
        uint256 threshold,
        Precision precision
    ) internal pure returns (uint256) {
        if (precision == Precision.Low && input < ONE_PREC_6) {
            return _sqrt(input * 10 ** 12, threshold, Precision.High) / 10 ** 12;
        }
        return _sqrt(input, threshold, precision);
    }

    /** @dev Implements square root algorithm using Newton's method and a first-guess optimisation **/
    function _sqrt(
        uint256 input,
        uint256 threshold,
        Precision precision
    ) internal pure returns (uint256) {
        if (input == 0) {
            return 0;
        }
        uint256 guess;
        uint256 decimals;
        uint256 one;
        if (precision == Precision.None) {
            decimals = 0;
            one = ONE_PREC_NONE;
            guess = 1 << _intLog2Halved(input);
        } else if (precision == Precision.Low) {
            decimals = 6;
            one = ONE_PREC_6;
            guess = _makeInitialGuessLowPrecision(input);
        } else if (precision == Precision.High) {
            decimals = 18;
            one = ONE_PREC_18;
            guess = _makeInitialGuess(input);
        }

        // 7 iterations
        guess = (guess + ((input * one) / guess)) / 2;
        guess = (guess + ((input * one) / guess)) / 2;
        guess = (guess + ((input * one) / guess)) / 2;
        guess = (guess + ((input * one) / guess)) / 2;
        guess = (guess + ((input * one) / guess)) / 2;
        guess = (guess + ((input * one) / guess)) / 2;
        guess = (guess + ((input * one) / guess)) / 2;

        // Check in some epsilon range
        // Check square is more or less correct
        uint256 guessSquared = guess.mulDown(guess, decimals);
        require(
            guessSquared <= input + (guess.mulDown(threshold, decimals)) &&
                guessSquared + (guess.mulDown(threshold, decimals)) >= input,
            "sqrt FAILED"
        );

        return guess;
    }

    function _makeInitialGuess(uint256 input) internal pure returns (uint256) {
        if (input >= ScaledMath.ONE) {
            return (1 << (_intLog2Halved(input / ScaledMath.ONE))) * ScaledMath.ONE;
        } else {
            if (input < 10) {
                return SQRT_1E_NEG_17;
            }
            if (input < 1e2) {
                return 1e10;
            }
            if (input < 1e3) {
                return SQRT_1E_NEG_15;
            }
            if (input < 1e4) {
                return 1e11;
            }
            if (input < 1e5) {
                return SQRT_1E_NEG_13;
            }
            if (input < 1e6) {
                return 1e12;
            }
            if (input < 1e7) {
                return SQRT_1E_NEG_11;
            }
            if (input < 1e8) {
                return 1e13;
            }
            if (input < 1e9) {
                return SQRT_1E_NEG_9;
            }
            if (input < 1e10) {
                return 1e14;
            }
            if (input < 1e11) {
                return SQRT_1E_NEG_7;
            }
            if (input < 1e12) {
                return 1e15;
            }
            if (input < 1e13) {
                return SQRT_1E_NEG_5;
            }
            if (input < 1e14) {
                return 1e16;
            }
            if (input < 1e15) {
                return SQRT_1E_NEG_3;
            }
            if (input < 1e16) {
                return 1e17;
            }
            if (input < 1e17) {
                return SQRT_1E_NEG_1;
            }
            return input;
        }
    }

    function _makeInitialGuessLowPrecision(uint256 input) internal pure returns (uint256) {
        if (input >= ONE_PREC_6) {
            return (1 << (_intLog2Halved(input / ONE_PREC_6))) * ONE_PREC_6;
        } else {
            revert("numbers under 1 not suported in the low precision square root");
        }
    }

    function _intLog2Halved(uint256 x) public pure returns (uint256 n) {
        if (x >= 1 << 128) {
            x >>= 128;
            n += 64;
        }
        if (x >= 1 << 64) {
            x >>= 64;
            n += 32;
        }
        if (x >= 1 << 32) {
            x >>= 32;
            n += 16;
        }
        if (x >= 1 << 16) {
            x >>= 16;
            n += 8;
        }
        if (x >= 1 << 8) {
            x >>= 8;
            n += 4;
        }
        if (x >= 1 << 4) {
            x >>= 4;
            n += 2;
        }
        if (x >= 1 << 2) {
            x >>= 2;
            n += 1;
        }
    }
}
