// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '../../modules/Lender/ILendingPlatform.sol';

interface ISimplePositionLendingConnector {
    function increaseSimplePositionWithFunds(
        address platform,
        address supplyToken,
        uint256 supplyAmount,
        address borrowToken,
        uint256 borrowAmount
    ) external;

    function decreaseSimplePositionWithFunds(
        address platform,
        address redeemToken,
        uint256 redeemAmount,
        address repayToken,
        uint256 repayAmount
    ) external;
}
