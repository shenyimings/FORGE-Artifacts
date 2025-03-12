//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LendingStorage.sol";

abstract contract LendingGetter is LendingStorage {
    function exchangeRateStored() public override view returns (uint256) {
        (MathError err, uint256 result) = exchangeRateStoredInternal();
        require(err == MathError.NO_ERROR, "Math error");
        return result;
    }

    function exchangeRateStoredInternal()
        internal
        view
        returns (MathError, uint256)
    {
        uint256 _totalSupply = _lToken.totalSupply();
        if (_totalSupply == 0) {
            return (MathError.NO_ERROR, initialExchangeRateMantissa);
        } else {
            uint256 totalCash = getCashPrior();
            uint256 cashPlusBorrowsMinusReserves;
            Exp memory exchangeRate;
            MathError mathErr;

            (mathErr, cashPlusBorrowsMinusReserves) = addThenSubUInt(
                totalCash,
                totalBorrows,
                totalReserves()
            );
            if (mathErr != MathError.NO_ERROR) {
                return (mathErr, 0);
            }

            (mathErr, exchangeRate) = getExp(
                cashPlusBorrowsMinusReserves,
                _totalSupply
            );
            if (mathErr != MathError.NO_ERROR) {
                return (mathErr, 0);
            }

            return (MathError.NO_ERROR, exchangeRate.mantissa);
        }
    }

    function borrowBalanceStored(address account)
        public 
        override
        view
        returns (uint256)
    {
        (MathError err, uint256 result) = borrowBalanceStoredInternal(account);
        require(err == MathError.NO_ERROR, "Math error");
        return result;
    }

    function borrowBalanceStoredInternal(address account)
        internal
        view
        returns (MathError, uint256)
    {
        MathError mathErr;
        uint256 principalTimesIndex;
        uint256 result;

        BorrowSnapshot storage borrowSnapshot = accountBorrows[account];

        if (borrowSnapshot.principal == 0) {
            return (MathError.NO_ERROR, 0);
        }

        (mathErr, principalTimesIndex) = mulUInt(
            borrowSnapshot.principal,
            borrowIndex
        );
        if (mathErr != MathError.NO_ERROR) {
            return (mathErr, 0);
        }

        (mathErr, result) = divUInt(
            principalTimesIndex,
            borrowSnapshot.interestIndex
        );
        if (mathErr != MathError.NO_ERROR) {
            return (mathErr, 0);
        }

        return (MathError.NO_ERROR, result);
    }

    function getAccountSnapshot(address account)
        external
        override
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 lTokenBalance = _lToken.balanceOf(account);
        uint256 borrowBalance;
        uint256 exchangeRateMantissa;

        MathError mErr;

        (mErr, borrowBalance) = borrowBalanceStoredInternal(account);
        if (mErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0, 0, 0);
        }

        (mErr, exchangeRateMantissa) = exchangeRateStoredInternal();
        if (mErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0, 0, 0);
        }

        return (
            uint256(Error.NO_ERROR),
            lTokenBalance,
            borrowBalance,
            exchangeRateMantissa
        );
    }

    function borrowRatePerBlock() external override view returns (uint256) {
        return
            _interestRateModel.getBorrowRate(
                getCashPrior(),
                totalBorrows,
                totalReserves()
            );
    }

    function supplyRatePerBlock() external override view returns (uint256) {
        return
            _interestRateModel.getSupplyRate(
                getCashPrior(),
                totalBorrows,
                totalReserves(),
                reserveFactorMantissa()
            );
    }

    function reserveFactorMantissa() public override view returns (uint256) {
        uint256 sumReserveFactorMantissa = platformReserveFactorMantissa +
            poolReserveFactorMantissa;
        require(
            sumReserveFactorMantissa >= platformReserveFactorMantissa,
            "Overflow"
        );
        return sumReserveFactorMantissa;
    }

    function totalReserves() public override view returns (uint256) {
        uint256 sumReserves = platformReserves + poolReserves;
        require(sumReserves >= platformReserves, "Overflow");
        return sumReserves;
    }

    function controller() external view override returns(address) {
        return address(_controller);
    }

    function lToken() external view override returns(address) {
        return address(_lToken);
    }

    function interestRateModel() external override view returns(address) {
        return address(_interestRateModel);
    }

    function getBlockNumber() internal view returns (uint256) {
        return block.number;
    }

    function getCash() external override view returns (uint256) {
        return getCashPrior();
    }

    function getCashPrior() internal view virtual returns (uint256);
}
