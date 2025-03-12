//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ILending.sol";
import "../interfaces/IYESController.sol";
import "../interfaces/IInterestRateModel.sol";
import "../interfaces/ILToken.sol";
import "../libraries/error/ErrorReporter.sol";
import "../libraries/math/Exponential.sol";
import "../modules/kap20/interfaces/IKAP20.sol";
import "../modules/security/ReentrancyGuard.sol";
import "../modules/admin/Authorization.sol";

abstract contract LendingStorage is
    ILending,
    TokenErrorReporter,
    Exponential,
    ReentrancyGuard,
    Authorization
{
    bool public override constant isLContract =  true;

    address public override underlyingToken;

    uint256 public override poolReserveFactorMantissa;
    uint256 public override platformReserveFactorMantissa;
    uint256 public override accrualBlockNumber;
    uint256 public override borrowIndex;
    uint256 public override totalBorrows;
    uint256 public override poolReserves;
    uint256 public override platformReserves;
    uint256 public override poolReserveExecutionPoint;
    uint256 public override platformReserveExecutionPoint;

    address payable public override beneficiary;

    uint256 public override slippageTolerrance = 0.005e18; //0.5%

    uint256 public override constant protocolSeizeShareMantissa = 2.8e16; //2.8%

    uint256 internal initialExchangeRateMantissa;
    uint256 internal constant borrowRateMaxMantissa = 0.0005e16;
    uint256 internal constant reserveFactorMaxMantissa = 1e18;

    IYESController internal _controller;
    IInterestRateModel internal _interestRateModel;
    ILToken internal _lToken;

    struct BorrowSnapshot {
        uint256 principal;
        uint256 interestIndex;
    }

    mapping(address => BorrowSnapshot) internal accountBorrows;

    enum TransferMethod {
        METAMASK,
        BK_NEXT
    }
}
