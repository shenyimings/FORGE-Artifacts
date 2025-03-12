//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

interface ILending {

    /*** Market Events ***/

    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);
    event Deposit(address user, uint depositAmount, uint mintTokens);
    event Withdraw(address user, uint withdrawAmount, uint withdrawTokens);
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, uint seizeTokens);

    /*** Admin Events ***/

    event NewController(address oldController, address newController);
    event NewMarketInterestRateModel(address oldInterestRateModel, address newInterestRateModel);
    event NewPlatformReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);
    event NewPoolReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);
    event PlatformReservesClaimed(address beneficiary, uint reduceAmount, uint newTotalReserves);
    event BoughtYES(uint spentAmount, uint yesAmount);
    event NewPlatformReserveExecutionPoint(uint oldPlatformReserveExecutionPoint, uint newPlatformReserveExecutionPoint);
    event NewPoolReserveExecutionPoint(uint oldPoolReserveExecutionPoint, uint newPoolReserveExecutionPoint);
    event NewBeneficiary(address payable oldBeneficiary, address payable newBeneficiary);
    event NewSlippageTolerrance(uint oldSlippageTolerrance, uint newSlippageTolerrance);


    // /*** User Interface ***/

    function isLContract() external returns (bool);

    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function accrueInterest() external returns (uint);

    function lToken() external view returns (address);
    function underlyingToken() external view returns (address);

    function controller() external view returns(address);
    function interestRateModel() external view returns(address);
    function reserveFactorMantissa() external view returns(uint);
    function poolReserveFactorMantissa() external view returns(uint);
    function platformReserveFactorMantissa() external view returns(uint);
    function accrualBlockNumber() external view returns(uint);
    function borrowIndex() external view returns(uint);
    function totalBorrows() external view returns (uint);
    function platformReserves() external view returns(uint);
    function poolReserves() external view returns(uint);
    function totalReserves() external view returns(uint);
    function protocolSeizeShareMantissa() external view returns(uint);
    function platformReserveExecutionPoint() external view returns(uint);
    function poolReserveExecutionPoint() external view returns(uint);
    function beneficiary() external view returns(address payable);
    function slippageTolerrance() external view returns(uint);

    /*** Admin Functions ***/

    function _setController(address newController) external returns (uint);
    function _setPlatformReserveFactor(uint newReserveFactorMantissa) external returns (uint);
    function _setPoolReserveFactor(uint newReserveFactorMantissa) external returns (uint);
    function _setInterestRateModel(address newInterestRateModel) external returns (uint);
    function _setPlatformReserveExecutionPoint(uint newPlatformReserveExecutionPoint) external returns (uint);
    function _setPoolReserveExecutionPoint(uint newPoolReserveExecutionPoint) external returns (uint);
    function _setBeneficiary(address payable newBeneficiary) external returns (uint);
    function _setSlippageTolerrance(uint newSlippageTolerrance) external returns (uint);
}