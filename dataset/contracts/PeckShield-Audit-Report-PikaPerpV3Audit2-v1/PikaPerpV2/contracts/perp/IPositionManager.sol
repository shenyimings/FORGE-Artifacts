// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPositionManager {
    function createOpenPosition(
        address _account,
        uint256 _productId,
        uint256 _margin,
        uint256 _leverage,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee,
        bytes32 _referralCode
    ) external payable;

    function createClosePosition(
        address _account,
        uint256 _productId,
        uint256 _margin,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee
    ) external payable;
}
