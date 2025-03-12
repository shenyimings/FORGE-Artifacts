//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LendingInterest.sol";

abstract contract LendingSetter is LendingInterest {
    
    function _setController(address newController)
        public
        override
        onlyAdmin
        returns (uint256)
    {
        IYESController oldController = _controller;
        _controller = IYESController(newController);

        require(_controller.isController(), "Controller error");

        emit NewController(address(oldController), newController);

        return uint256(Error.NO_ERROR);
    }

    function _setInterestRateModel(address newInterestRateModel)
        public
        override
        onlyAdmin
        returns (uint256)
    {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(
                    Error(error),
                    FailureInfo.SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED
                );
        }
        return _setInterestRateModelFresh(newInterestRateModel);
    }

    function _setInterestRateModelFresh(address newInterestRateModel)
        internal
        returns (uint256)
    {
        IInterestRateModel oldInterestRateModel;

        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.SET_INTEREST_RATE_MODEL_FRESH_CHECK
                );
        }

        oldInterestRateModel = _interestRateModel;
        _interestRateModel = IInterestRateModel(newInterestRateModel);

        require(_interestRateModel.isInterestRateModel(), "Interest model error");

        emit NewMarketInterestRateModel(
            address(oldInterestRateModel),
            newInterestRateModel
        );

        return uint256(Error.NO_ERROR);
    }

    function _setPlatformReserveFactor(uint256 newPlatformReserveFactorMantissa)
        external
        override
        nonReentrant
        onlyAdmin
        returns (uint256)
    {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(
                    Error(error),
                    FailureInfo
                        .SET_PLATFORM_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED
                );
        }
        return _setPlatformReserveFactorFresh(newPlatformReserveFactorMantissa);
    }

    function _setPlatformReserveFactorFresh(
        uint256 newPlatformReserveFactorMantissa
    ) internal returns (uint256) {
        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.SET_PLATFORM_RESERVE_FACTOR_FRESH_CHECK
                );
        }

        uint256 newTotalReserveFactorMantissa = newPlatformReserveFactorMantissa +
                poolReserveFactorMantissa;

        if (newTotalReserveFactorMantissa > reserveFactorMaxMantissa) {
            return
                fail(
                    Error.BAD_INPUT,
                    FailureInfo.SET_PLATFORM_RESERVE_FACTOR_BOUNDS_CHECK
                );
        }

        uint256 oldPlatformReserveFactorMantissa = platformReserveFactorMantissa;
        platformReserveFactorMantissa = newPlatformReserveFactorMantissa;

        emit NewPlatformReserveFactor(
            oldPlatformReserveFactorMantissa,
            newPlatformReserveFactorMantissa
        );

        return uint256(Error.NO_ERROR);
    }

    function _setPoolReserveFactor(uint256 newPoolReserveFactorMantissa)
        external
        override
        nonReentrant
        onlyAdmin
        returns (uint256)
    {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(
                    Error(error),
                    FailureInfo.SET_POOL_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED
                );
        }
        return _setPoolReserveFactorFresh(newPoolReserveFactorMantissa);
    }

    function _setPoolReserveFactorFresh(uint256 newPoolReserveFactorMantissa)
        internal
        returns (uint256)
    {
        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.SET_POOL_RESERVE_FACTOR_FRESH_CHECK
                );
        }

        uint256 newTotalReserveFactorMantissa = platformReserveFactorMantissa +
            newPoolReserveFactorMantissa;
        if (newTotalReserveFactorMantissa > reserveFactorMaxMantissa) {
            return
                fail(
                    Error.BAD_INPUT,
                    FailureInfo.SET_POOL_RESERVE_FACTOR_BOUNDS_CHECK
                );
        }

        uint256 oldPoolReserveFactorMantissa = poolReserveFactorMantissa;
        poolReserveFactorMantissa = newPoolReserveFactorMantissa;

        emit NewPoolReserveFactor(
            oldPoolReserveFactorMantissa,
            newPoolReserveFactorMantissa
        );

        return uint256(Error.NO_ERROR);
    }

    function _setPlatformReserveExecutionPoint(
        uint256 newPlatformReserveExecutionPoint
    ) external override nonReentrant onlyAdmin returns (uint256) {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(
                    Error(error),
                    FailureInfo
                        .SET_PLATFORM_RESERVE_EXECUTION_POINT_ACCRUE_INTEREST_FAILED
                );
        }
        return
            _setPlatformReserveExecutionPointFresh(
                newPlatformReserveExecutionPoint
            );
    }

    function _setPlatformReserveExecutionPointFresh(
        uint256 newPlatformReserveExecutionPoint
    ) internal returns (uint256) {
        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.SET_PLATFORM_RESERVE_EXECUTION_POINT_FRESH_CHECK
                );
        }

        uint256 oldPlatformReserveExecutionPoint = platformReserveExecutionPoint;
        platformReserveExecutionPoint = newPlatformReserveExecutionPoint;

        emit NewPlatformReserveExecutionPoint(
            oldPlatformReserveExecutionPoint,
            newPlatformReserveExecutionPoint
        );

        return uint256(Error.NO_ERROR);
    }

    function _setPoolReserveExecutionPoint(uint256 newPoolReserveExecutionPoint)
        external
        override
        nonReentrant
        onlyAdmin
        returns (uint256)
    {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(
                    Error(error),
                    FailureInfo
                        .SET_POOL_RESERVE_EXECUTION_POINT_ACCRUE_INTEREST_FAILED
                );
        }
        return _setPoolReserveExecutionPointFresh(newPoolReserveExecutionPoint);
    }

    function _setPoolReserveExecutionPointFresh(
        uint256 newPoolReserveExecutionPoint
    ) internal returns (uint256) {
        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.SET_POOL_RESERVE_EXECUTION_POINT_FRESH_CHECK
                );
        }

        uint256 oldPoolReserveExecutionPoint = poolReserveExecutionPoint;
        poolReserveExecutionPoint = newPoolReserveExecutionPoint;

        emit NewPoolReserveExecutionPoint(
            oldPoolReserveExecutionPoint,
            newPoolReserveExecutionPoint
        );

        return uint256(Error.NO_ERROR);
    }

    function _setBeneficiary(address payable newBeneficiary)
        external
        override
        nonReentrant
        onlyAdmin
        returns (uint256)
    {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(
                    Error(error),
                    FailureInfo.SET_BENEFICIARY_ACCRUE_INTEREST_FAILED
                );
        }
        return _setBeneficiaryFresh(newBeneficiary);
    }

    function _setBeneficiaryFresh(address payable newBeneficiary)
        internal
        returns (uint256)
    {
        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.SET_BENEFICIARY_FRESH_CHECK
                );
        }

        address payable oldBeneficiary = beneficiary;
        beneficiary = newBeneficiary;

        emit NewBeneficiary(oldBeneficiary, newBeneficiary);

        return uint256(Error.NO_ERROR);
    }

    function _setSlippageTolerrance(uint256 newSlippageTolerrance)
        external
        override
        nonReentrant
        onlyAdmin
        returns (uint256)
    {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(
                    Error(error),
                    FailureInfo.SET_SLIPPAGE_TOLERRANCE_ACCRUE_INTEREST_FAILED
                );
        }
        return _setSlippageTolerranceFresh(newSlippageTolerrance);
    }

    function _setSlippageTolerranceFresh(uint256 newSlippageTolerrance)
        internal
        returns (uint256)
    {
        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.SET_SLIPPAGE_TOLERRANCE_FRESH_CHECK
                );
        }

        uint256 oldSlippageTolerrance = slippageTolerrance;
        slippageTolerrance = newSlippageTolerrance;

        emit NewSlippageTolerrance(
            oldSlippageTolerrance,
            newSlippageTolerrance
        );

        return uint256(Error.NO_ERROR);
    }

}
