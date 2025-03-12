// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./IInterestRate.sol";
import "./ILongVoucher.sol";
import "./IVoucherProvider.sol";

interface IProductCenter is IVoucherProvider {
    struct ProductParameters {
        uint256 totalQuota;
        uint256 minSubscriptionAmount;
        uint256 beginSubscriptionBlock;
        uint256 endSubscriptionBlock;
        uint256 minHoldingDuration;
        IInterestRate interestRate;
    }

    struct Subscription {
        address subscriber;
        uint256 atBlock;
        uint256 principal;
        uint256 voucherId;
    }

    function isAdmin(address account) external view returns (bool);

    function isOperator(uint256 productId, address account) external view returns (bool);

    function productCount() external view returns (uint256);

    function productIdByIndex(uint256 index_) external view returns (uint256);

    function getProductParameters(uint256 productId) external view returns (ProductParameters memory);

    function getTotalEquities(uint256 productId) external view returns (uint256);

    function getTotalFundsRaised(uint256 productId) external view returns (uint256);

    function getTotalFundsLoaned(uint256 productId) external view returns (uint256);

    function isSubscriber(uint256 productId, address subscriber) external view returns (bool);

    function getSubscription(uint256 productId, address subscriber) external view returns (Subscription memory);

    function voucherInterest(uint256 voucherId) external view returns (uint256);

    function productInterest(uint256 productId) external view returns (uint256);
}