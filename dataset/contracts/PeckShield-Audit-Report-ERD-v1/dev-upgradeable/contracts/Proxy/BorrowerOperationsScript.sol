// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../Interfaces/IBorrowerOperations.sol";

contract BorrowerOperationsScript {
    IBorrowerOperations immutable borrowerOperations;

    constructor(IBorrowerOperations _borrowerOperations) {
        borrowerOperations = _borrowerOperations;
    }

    function openTrove(
        address[] memory _colls,
        uint256[] memory _amounts,
        uint256 _maxFeePercentage,
        uint256 _EUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        borrowerOperations.openTrove(
            _colls,
            _amounts,
            _maxFeePercentage,
            _EUSDAmount,
            _upperHint,
            _lowerHint
        );
    }

    function addColl(
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address _upperHint,
        address _lowerHint
    ) external payable {
        borrowerOperations.addColl(
            _collsIn,
            _amountsIn,
            _upperHint,
            _lowerHint
        );
    }

    function withdrawColl(
        address[] memory _collsOut,
        uint256[] memory _amountsOut,
        address _upperHint,
        address _lowerHint
    ) external {
        borrowerOperations.withdrawColl(
            _collsOut,
            _amountsOut,
            _upperHint,
            _lowerHint
        );
    }

    function withdrawEUSD(
        uint256 _amount,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFee
    ) external {
        borrowerOperations.withdrawEUSD(
            _amount,
            _upperHint,
            _lowerHint,
            _maxFee
        );
    }

    function repayEUSD(
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external {
        borrowerOperations.repayEUSD(_amount, _upperHint, _lowerHint);
    }

    function closeTrove() external {
        borrowerOperations.closeTrove();
    }

    function adjustTrove(
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address[] memory _collsOut,
        uint256[] memory _amountsOut,
        uint256 _maxFeePercentage,
        uint256 _EUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable {
        borrowerOperations.adjustTrove(
            _collsIn,
            _amountsIn,
            _collsOut,
            _amountsOut,
            _maxFeePercentage,
            _EUSDChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );
    }

    function claimCollateral() external {
        borrowerOperations.claimCollateral();
    }
}
