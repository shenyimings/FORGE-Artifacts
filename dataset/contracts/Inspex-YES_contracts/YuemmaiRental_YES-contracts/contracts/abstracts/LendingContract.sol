//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LendingSetter.sol";
import "../interfaces/IYESVault.sol";
import "../libraries/parser/Parser.sol";
import "../LToken.sol";
import "../modules/kyc/KYCHandler.sol";
import "../modules/kyc/interfaces/IKYCBitkubChain.sol";

abstract contract LendingContract is LendingSetter {
    constructor(
        address controller_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory lTokenName_,
        string memory lTokenSymbol_,
        uint8 lTokenDecimals_,
        address committee_,
        address adminRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    ) Authorization(adminRouter_) {
        require(initialExchangeRateMantissa_ > 0, "Invalid exchange rate");
        initialExchangeRateMantissa = initialExchangeRateMantissa_;

        _setController(controller_);

        accrualBlockNumber = getBlockNumber();
        borrowIndex = mantissaOne;

        uint256 err = _setInterestRateModelFresh(interestRateModel_);
        require(err == uint256(Error.NO_ERROR), "Interest model failed");

        _lToken = new LToken(
            lTokenName_,
            lTokenSymbol_,
            lTokenDecimals_,
            committee_,
            adminRouter_,
            kyc_,
            acceptedKycLevel_
        );
    }

    function depositInternal(
        address user,
        uint256 depositAmount,
        TransferMethod method
    ) internal nonReentrant returns (uint256, uint256) {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return (
                fail(Error(error), FailureInfo.DEPOSIT_ACCRUE_INTEREST_FAILED),
                0
            );
        }
        return depositFresh(user, depositAmount, method);
    }

    struct DepositLocalVars {
        Error err;
        MathError mathErr;
        uint256 exchangeRateMantissa;
        uint256 mintTokens;
        uint256 totalSupplyNew;
        uint256 accountTokensNew;
        uint256 actualDepositAmount;
    }

    function depositFresh(
        address user,
        uint256 depositAmount,
        TransferMethod method
    ) internal returns (uint256, uint256) {
        uint256 allowed = _controller.depositAllowed(address(this));
        if (allowed != 0) {
            return (
                failOpaque(
                    Error.CONTROLLER_REJECTION,
                    FailureInfo.DEPOSIT_CONTROLLER_REJECTION,
                    allowed
                ),
                0
            );
        }

        if (accrualBlockNumber != getBlockNumber()) {
            return (
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.DEPOSIT_FRESHNESS_CHECK
                ),
                0
            );
        }

        DepositLocalVars memory vars;

        (
            vars.mathErr,
            vars.exchangeRateMantissa
        ) = exchangeRateStoredInternal();
        if (vars.mathErr != MathError.NO_ERROR) {
            return (
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo.DEPOSIT_EXCHANGE_RATE_READ_FAILED,
                    uint256(vars.mathErr)
                ),
                0
            );
        }

        vars.actualDepositAmount = doTransferIn(user, depositAmount, method);

        (vars.mathErr, vars.mintTokens) = divScalarByExpTruncate(
            vars.actualDepositAmount,
            Exp({mantissa: vars.exchangeRateMantissa})
        );
        require(
            vars.mathErr == MathError.NO_ERROR,
            "Exchange calculate failed"
        );

        _lToken.mint(user, vars.mintTokens);

        emit Deposit(user, vars.actualDepositAmount, vars.mintTokens);

        return (uint256(Error.NO_ERROR), vars.actualDepositAmount);
    }

    function withdrawInternal(address payable user, uint256 withdrawTokens, TransferMethod method)
        internal
        nonReentrant
        returns (uint256)
    {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(Error(error), FailureInfo.WITHDRAW_ACCRUE_INTEREST_FAILED);
        }
        return withdrawFresh(user, withdrawTokens, 0, method);
    }

    function withdrawUnderlyingInternal(
        address payable user,
        uint256 withdrawAmount,
        TransferMethod method
    ) internal nonReentrant returns (uint256) {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(Error(error), FailureInfo.WITHDRAW_ACCRUE_INTEREST_FAILED);
        }
        return withdrawFresh(user, 0, withdrawAmount, method);
    }

    struct WithdrawLocalVars {
        Error err;
        MathError mathErr;
        uint256 exchangeRateMantissa;
        uint256 withdrawTokens;
        uint256 withdrawAmount;
        uint256 totalSupplyNew;
        uint256 accountTokensNew;
    }

    function withdrawFresh(
        address payable user,
        uint256 withdrawTokensIn,
        uint256 withdrawAmountIn,
        TransferMethod method
    ) internal returns (uint256) {
        require(
            withdrawTokensIn == 0 || withdrawAmountIn == 0,
            "Must have a zero input"
        );

        WithdrawLocalVars memory vars;

        (
            vars.mathErr,
            vars.exchangeRateMantissa
        ) = exchangeRateStoredInternal();
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo.WITHDRAW_EXCHANGE_RATE_READ_FAILED,
                    uint256(vars.mathErr)
                );
        }

        if (withdrawTokensIn > 0) {
            vars.withdrawTokens = withdrawTokensIn;

            (vars.mathErr, vars.withdrawAmount) = mulScalarTruncate(
                Exp({mantissa: vars.exchangeRateMantissa}),
                withdrawTokensIn
            );
            if (vars.mathErr != MathError.NO_ERROR) {
                return
                    failOpaque(
                        Error.MATH_ERROR,
                        FailureInfo.WITHDRAW_EXCHANGE_TOKENS_CALCULATION_FAILED,
                        uint256(vars.mathErr)
                    );
            }
        } else {
            (vars.mathErr, vars.withdrawTokens) = divScalarByExpTruncate(
                withdrawAmountIn,
                Exp({mantissa: vars.exchangeRateMantissa})
            );
            if (vars.mathErr != MathError.NO_ERROR) {
                return
                    failOpaque(
                        Error.MATH_ERROR,
                        FailureInfo.WITHDRAW_EXCHANGE_AMOUNT_CALCULATION_FAILED,
                        uint256(vars.mathErr)
                    );
            }

            vars.withdrawAmount = withdrawAmountIn;
        }

        uint256 allowed = _controller.withdrawAllowed(address(this), user);
        if (allowed != 0) {
            return
                failOpaque(
                    Error.CONTROLLER_REJECTION,
                    FailureInfo.WITHDRAW_CONTROLLER_REJECTION,
                    allowed
                );
        }

        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.WITHDRAW_FRESHNESS_CHECK
                );
        }

        if (getCashPrior() < vars.withdrawAmount) {
            return
                fail(
                    Error.TOKEN_INSUFFICIENT_CASH,
                    FailureInfo.WITHDRAW_TRANSFER_OUT_NOT_POSSIBLE
                );
        }

        doTransferOut(user, vars.withdrawAmount, method);

        _lToken.burn(user, vars.withdrawTokens);

        emit Withdraw(user, vars.withdrawAmount, vars.withdrawTokens);

        return uint256(Error.NO_ERROR);
    }

    function borrowInternal(address payable borrower, uint256 borrowAmount, TransferMethod method)
        internal
        nonReentrant
        returns (uint256)
    {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return
                fail(Error(error), FailureInfo.BORROW_ACCRUE_INTEREST_FAILED);
        }
        return borrowFresh(borrower, borrowAmount, method);
    }

    struct BorrowLocalVars {
        MathError mathErr;
        uint256 accountBorrows;
        uint256 accountBorrowsNew;
        uint256 totalBorrowsNew;
    }

    function borrowFresh(address payable borrower, uint256 borrowAmount, TransferMethod method)
        internal
        returns (uint256)
    {
        uint256 allowed = _controller.borrowAllowed(
            address(this),
            borrower,
            borrowAmount
        );
        if (allowed != 0) {
            return
                failOpaque(
                    Error.CONTROLLER_REJECTION,
                    FailureInfo.BORROW_CONTROLLER_REJECTION,
                    allowed
                );
        }

        if (accrualBlockNumber != getBlockNumber()) {
            return
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.BORROW_FRESHNESS_CHECK
                );
        }

        if (getCashPrior() < borrowAmount) {
            return
                fail(
                    Error.TOKEN_INSUFFICIENT_CASH,
                    FailureInfo.BORROW_CASH_NOT_AVAILABLE
                );
        }

        BorrowLocalVars memory vars;

        (vars.mathErr, vars.accountBorrows) = borrowBalanceStoredInternal(
            borrower
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo.BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        (vars.mathErr, vars.accountBorrowsNew) = addUInt(
            vars.accountBorrows,
            borrowAmount
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo
                        .BORROW_NEW_ACCOUNT_BORROW_BALANCE_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        (vars.mathErr, vars.totalBorrowsNew) = addUInt(
            totalBorrows,
            borrowAmount
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo.BORROW_NEW_TOTAL_BALANCE_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                );
        }

        doTransferOut(borrower, borrowAmount, method);

        accountBorrows[borrower].principal = vars.accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = vars.totalBorrowsNew;

        emit Borrow(
            borrower,
            borrowAmount,
            vars.accountBorrowsNew,
            vars.totalBorrowsNew
        );

        return uint256(Error.NO_ERROR);
    }

    function repayBorrowInternal(
        address borrower,
        uint256 repayAmount,
        TransferMethod method
    ) internal nonReentrant returns (uint256, uint256) {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return (
                fail(
                    Error(error),
                    FailureInfo.REPAY_BORROW_ACCRUE_INTEREST_FAILED
                ),
                0
            );
        }
        return repayBorrowFresh(borrower, borrower, repayAmount, method);
    }

    function repayBorrowBehalfInternal(
        address payer,
        address borrower,
        uint256 repayAmount,
        TransferMethod method
    ) internal nonReentrant returns (uint256, uint256) {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return (
                fail(
                    Error(error),
                    FailureInfo.REPAY_BEHALF_ACCRUE_INTEREST_FAILED
                ),
                0
            );
        }
        return repayBorrowFresh(payer, borrower, repayAmount, method);
    }

    struct RepayBorrowLocalVars {
        Error err;
        MathError mathErr;
        uint256 repayAmount;
        uint256 borrowerIndex;
        uint256 accountBorrows;
        uint256 accountBorrowsNew;
        uint256 totalBorrowsNew;
        uint256 actualRepayAmount;
    }

    function repayBorrowFresh(
        address payer,
        address borrower,
        uint256 repayAmount,
        TransferMethod method
    ) internal returns (uint256, uint256) {
        uint256 allowed = _controller.repayBorrowAllowed(address(this));
        if (allowed != 0) {
            return (
                failOpaque(
                    Error.CONTROLLER_REJECTION,
                    FailureInfo.REPAY_BORROW_CONTROLLER_REJECTION,
                    allowed
                ),
                0
            );
        }

        if (accrualBlockNumber != getBlockNumber()) {
            return (
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.REPAY_BORROW_FRESHNESS_CHECK
                ),
                0
            );
        }

        RepayBorrowLocalVars memory vars;

        vars.borrowerIndex = accountBorrows[borrower].interestIndex;

        (vars.mathErr, vars.accountBorrows) = borrowBalanceStoredInternal(
            borrower
        );
        if (vars.mathErr != MathError.NO_ERROR) {
            return (
                failOpaque(
                    Error.MATH_ERROR,
                    FailureInfo
                        .REPAY_BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED,
                    uint256(vars.mathErr)
                ),
                0
            );
        }

        if (repayAmount == type(uint256).max) {
            vars.repayAmount = vars.accountBorrows;
        } else if (repayAmount > vars.accountBorrows) {
            vars.repayAmount = vars.accountBorrows;
        } else if (repayAmount > totalBorrows) {
            vars.repayAmount = totalBorrows;
        } else {
            vars.repayAmount = repayAmount;
        }

        if (payer != address(this)) {
            vars.actualRepayAmount = doTransferIn(
                payer,
                vars.repayAmount,
                method
            );
        } else {
            vars.actualRepayAmount = vars.repayAmount;
        }

        (vars.mathErr, vars.accountBorrowsNew) = subUInt(
            vars.accountBorrows,
            vars.actualRepayAmount
        );
        require(
            vars.mathErr == MathError.NO_ERROR,
            "Account borrow update failed"
        );

        (vars.mathErr, vars.totalBorrowsNew) = subUInt(
            totalBorrows,
            vars.actualRepayAmount
        );
        require(
            vars.mathErr == MathError.NO_ERROR,
            "Total borrow update failed"
        );

        accountBorrows[borrower].principal = vars.accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = vars.totalBorrowsNew;

        if (platformReserves >= platformReserveExecutionPoint) {
            _claimPlatformReserves(platformReserves);
        }

        if (poolReserves > 0 && poolReserves >= poolReserveExecutionPoint) {
            _buyYES(poolReserves);
        }

        emit RepayBorrow(
            payer,
            borrower,
            vars.actualRepayAmount,
            vars.accountBorrowsNew,
            vars.totalBorrowsNew
        );

        return (uint256(Error.NO_ERROR), vars.actualRepayAmount);
    }

    function liquidateBorrowInternal(
        address payable liquidator,
        address borrower,
        TransferMethod method
    ) internal nonReentrant returns (uint256, uint256) {
        uint256 error = accrueInterest();
        if (error != uint256(Error.NO_ERROR)) {
            return (
                fail(
                    Error(error),
                    FailureInfo.LIQUIDATE_ACCRUE_BORROW_INTEREST_FAILED
                ),
                0
            );
        }

        return liquidateBorrowFresh(liquidator, borrower, method);
    }

    function liquidateBorrowFresh(address payable liquidator, address borrower, TransferMethod method)
        internal
        returns (uint256, uint256)
    {
        uint256 allowed = _controller.liquidateBorrowAllowed(
            address(this),
            borrower
        );
        if (allowed != 0) {
            return (
                failOpaque(
                    Error.CONTROLLER_REJECTION,
                    FailureInfo.LIQUIDATE_CONTROLLER_REJECTION,
                    allowed
                ),
                0
            );
        }

        if (accrualBlockNumber != getBlockNumber()) {
            return (
                fail(
                    Error.MARKET_NOT_FRESH,
                    FailureInfo.LIQUIDATE_FRESHNESS_CHECK
                ),
                0
            );
        }

        if (borrower == liquidator) {
            return (
                fail(
                    Error.INVALID_ACCOUNT_PAIR,
                    FailureInfo.LIQUIDATE_LIQUIDATOR_IS_BORROWER
                ),
                0
            );
        }

        MathError mErr;
        uint256 borrowBalance;

        (mErr, borrowBalance) = borrowBalanceStoredInternal(borrower);

        (uint256 amountSeizeError, uint256 seizeTokens) = _controller
            .liquidateCalculateSeizeTokens(address(this), borrowBalance);
        require(
            amountSeizeError == uint256(Error.NO_ERROR),
            "Calculate seize amount failed"
        );

        IYESVault yesVault = IYESVault(_controller.yesVault());
        uint256 output = yesVault.sellMarket(borrower, seizeTokens);

        (
            uint256 repayBorrowError,
            uint256 actualRepayAmount
        ) = repayBorrowFresh(
                address(this),
                borrower,
                borrowBalance,
                TransferMethod.METAMASK
            );
        if (repayBorrowError != uint256(Error.NO_ERROR)) {
            return (
                fail(
                    Error(repayBorrowError),
                    FailureInfo.LIQUIDATE_REPAY_BORROW_FRESH_FAILED
                ),
                0
            );
        }

        doTransferOut(liquidator, output - actualRepayAmount, method);

        emit LiquidateBorrow(
            liquidator,
            borrower,
            actualRepayAmount,
            seizeTokens
        );

        return (uint256(Error.NO_ERROR), actualRepayAmount);
    }

    /*** Fresh getters ***/

    function exchangeRateCurrent()
        public
        override
        nonReentrant
        returns (uint256)
    {
        require(
            accrueInterest() == uint256(Error.NO_ERROR),
            "Accrue interest failed"
        );
        return exchangeRateStored();
    }

    function borrowBalanceCurrent(address account)
        external
        override
        nonReentrant
        returns (uint256)
    {
        require(
            accrueInterest() == uint256(Error.NO_ERROR),
            "Accrue interest failed"
        );
        return borrowBalanceStored(account);
    }

    function totalBorrowsCurrent()
        external
        override
        nonReentrant
        returns (uint256)
    {
        require(
            accrueInterest() == uint256(Error.NO_ERROR),
            "Accrue interest failed"
        );
        return totalBorrows;
    }

    function balanceOfUnderlying(address owner)
        external
        override
        returns (uint256)
    {
        Exp memory exchangeRate = Exp({mantissa: exchangeRateCurrent()});
        (MathError mErr, uint256 balance) = mulScalarTruncate(
            exchangeRate,
            _lToken.balanceOf(owner)
        );
        require(mErr == MathError.NO_ERROR, "Math error");
        return balance;
    }

    /*** Protocol functions ***/

    function _claimPlatformReserves(uint256 claimedAmount)
        private
        returns (uint256)
    {
        uint256 platformReservesNew;

        if (beneficiary == address(0)) {
            return
                fail(
                    Error.INVALID_BENEFICIARY,
                    FailureInfo.CLAIM_PLATFORM_RESERVES_INVALID_BENEFICIARY
                );
        }

        if (getCashPrior() < claimedAmount) {
            return
                fail(
                    Error.TOKEN_INSUFFICIENT_CASH,
                    FailureInfo.CLAIM_PLATFORM_RESERVES_CASH_NOT_AVAILABLE
                );
        }

        if (claimedAmount > platformReserves) {
            return
                fail(
                    Error.BAD_INPUT,
                    FailureInfo.CLAIM_PLATFORM_RESERVES_VALIDATION
                );
        }

        platformReservesNew = platformReserves - claimedAmount;
        require(platformReservesNew <= platformReserves, "Overflow");

        platformReserves = platformReservesNew;

        doTransferOut(beneficiary, claimedAmount, TransferMethod.METAMASK);

        emit PlatformReservesClaimed(
            beneficiary,
            claimedAmount,
            platformReservesNew
        );

        return uint256(Error.NO_ERROR);
    }

    function _buyYES(uint256 spentAmount) private returns (uint256) {
        uint256 poolReservesNew;
        IYESVault yesVault;
        address yesToken;
        address marketImpl;
        address market;

        yesVault = IYESVault(_controller.yesVault());
        yesToken = yesVault.yesToken();
        marketImpl = yesVault.marketImpl();
        market = yesVault.market();

        if (getCashPrior() < spentAmount) {
            return
                fail(
                    Error.TOKEN_INSUFFICIENT_CASH,
                    FailureInfo.BUY_YES_CASH_NOT_AVAILABLE
                );
        }

        if (spentAmount > poolReserves) {
            return fail(Error.BAD_INPUT, FailureInfo.BUY_YES_VALIDATION);
        }

        poolReservesNew = poolReserves - spentAmount;
        require(poolReservesNew <= poolReserves, "Overflow");

        poolReserves = poolReservesNew;

        (bool success, bytes memory data) = marketImpl.delegatecall(
            abi.encodeWithSignature(
                "marketBuy(address,address,address,uint256,address,uint256)",
                market,
                underlyingToken,
                yesToken,
                spentAmount,
                address(this),
                slippageTolerrance
            )
        );

        require(success, "Delegatecall failed");

        uint256 amountOut = Parser.toUint256(data);

        success = IKAP20(yesToken).transfer(address(yesVault), amountOut);
        require(success, "Transfer failed");

        emit BoughtYES(spentAmount, amountOut);

        return uint256(Error.NO_ERROR);
    }

    /*** BK Next helpers ***/
    function requireKYC(address sender) internal {
        IKYCBitkubChain kyc = _lToken.kyc();
        require(
            kyc.kycsLevel(sender) >= _lToken.acceptedKycLevel(),
            "only Bitkub Next user"
        );
    }

    /*** Token functions ***/
    function doTransferIn(
        address from,
        uint256 amount,
        TransferMethod method
    ) internal virtual returns (uint256);

    function doTransferOut(
        address payable to,
        uint256 amount,
        TransferMethod method
    ) internal virtual;
}
