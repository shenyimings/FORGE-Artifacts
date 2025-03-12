// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IRecommendationCenter {
    function beforeEquitiesTransfer(
        address productCenter_,
        uint256 productId_,
        address from_,
        address to_,
        uint256 fromVoucherId_,
        uint256 toVoucherId_,
        uint256 value_
    ) external;

    function afterEquitiesTransfer(
        address productCenter_,
        uint256 productId_,
        address from_,
        address to_,
        uint256 fromVoucherId_,
        uint256 toVoucherId_,
        uint256 value_
    ) external;
}
