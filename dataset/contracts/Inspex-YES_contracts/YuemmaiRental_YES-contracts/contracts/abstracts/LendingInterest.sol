//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LendingGetter.sol";

abstract contract LendingInterest is LendingGetter {

    struct AccrueInterestLocalVars {
        Error err;
        MathError mathErr;
        uint256 currentBlockNumber;
        uint256 accrualBlockNumberPrior;
        uint256 cashPrior;
        uint256 borrowsPrior;
        uint256 poolReservesPrior;
        uint256 platformReservesPrior;
        uint256 totalReservesPrior;
        uint256 borrowIndexPrior;
        uint256 borrowRateMantissa;
        uint256 blockDelta;
    }

    function accrueInterest() public override returns (uint256) {
        AccrueInterestLocalVars memory vars;

        vars.currentBlockNumber = getBlockNumber();
        vars.accrualBlockNumberPrior = accrualBlockNumber;

        if (vars.accrualBlockNumberPrior == vars.currentBlockNumber) {
            return uint256(Error.NO_ERROR);
        }

        vars.cashPrior = getCashPrior();
        vars.borrowsPrior = totalBorrows;
        vars.poolReservesPrior = poolReserves;
        vars.platformReservesPrior = platformReserves;
        vars.borrowIndexPrior = borrowIndex;

        vars.borrowRateMantissa = _interestRateModel.getBorrowRate(
            vars.cashPrior,
            vars.borrowsPrior,
            totalReserves()
        );

        require(
            vars.borrowRateMantissa <= borrowRateMaxMantissa,
            "Too high borrow rate"
        );

        (vars.mathErr, vars.blockDelta) = subUInt(
            vars.currentBlockNumber,
            vars.accrualBlockNumberPrior
        );
        require(
            vars.mathErr == MathError.NO_ERROR,
            "Calculate block delta failed"
        );

        Exp memory simpleInterestFactor;
        uint256 interestAccumulated;
        uint256 totalBorrowsNew;
        uint256 platformReservesNew;
        uint256 poolReservesNew;
        uint256 borrowIndexNew;

        (vars.mathErr, simpleInterestFactor) = mulScalar(
            Exp({mantissa: vars.borrowRateMantissa}),
            vars.blockDelta
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo
                        .ACCRUE_INTEREST_SIMPLE_INTEREST_FACTOR_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        (vars.mathErr, interestAccumulated) = mulScalarTruncate(
            simpleInterestFactor,
            vars.borrowsPrior
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo
                        .ACCRUE_INTEREST_ACCUMULATED_INTEREST_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        (vars.mathErr, totalBorrowsNew) = addUInt(
            interestAccumulated,
            vars.borrowsPrior
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo
                        .ACCRUE_INTEREST_NEW_TOTAL_BORROWS_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        (vars.mathErr, platformReservesNew) = mulScalarTruncateAddUInt(
            Exp({mantissa: platformReserveFactorMantissa}),
            interestAccumulated,
            vars.platformReservesPrior
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo
                        .ACCRUE_INTEREST_NEW_PLATFORM_RESERVES_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        (vars.mathErr, poolReservesNew) = mulScalarTruncateAddUInt(
            Exp({mantissa: poolReserveFactorMantissa}),
            interestAccumulated,
            vars.poolReservesPrior
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo
                        .ACCRUE_INTEREST_NEW_PLATFORM_RESERVES_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        (vars.mathErr, borrowIndexNew) = mulScalarTruncateAddUInt(
            simpleInterestFactor,
            vars.borrowIndexPrior,
            vars.borrowIndexPrior
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo
                        .ACCRUE_INTEREST_NEW_BORROW_INDEX_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        accrualBlockNumber = vars.currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        platformReserves = platformReservesNew;
        poolReserves = poolReservesNew;

        emit AccrueInterest(
            vars.cashPrior,
            interestAccumulated,
            borrowIndexNew,
            totalBorrowsNew
        );

        return uint256(Error.NO_ERROR);
    }
}
