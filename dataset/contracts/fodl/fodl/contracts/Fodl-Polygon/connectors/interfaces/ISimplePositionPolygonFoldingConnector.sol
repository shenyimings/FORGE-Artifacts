// SPDX-License-Identifier: MIT

pragma solidity 0.6;

interface ISimplePositionPolygonFoldingConnector {
    /**
     * platform - The lender, ex. Venus Comptroller
     * supplyToken - The principal and supplied token to platform
     * principalAmount - Amount to transferFrom accountOwner
     * minSupplyAmount - Increase position by at least this amount of supply, or revert. Used to protect from unwanted slippage
     * borrowToken - The borrowed token from platform
     * totalBorrowAmount - Increase position by borrowing exactly this amount of borrowToken in total from platform. Used to control target leverage
     * exchangeData - ABI encoded (bytes1, address[]), for (getExchangerAdapter, swapPath). Required for swapping borrowToken to supplyToken, when not same token
     */
    function increaseSimplePositionWithLoop(
        address platform,
        address supplyToken,
        uint256 principalAmount,
        uint256 minSupplyAmount,
        address borrowToken,
        uint256 totalBorrowAmount,
        bytes memory exchangeData
    ) external;

    /**
     * platform - The lender, ex. Venus Comptroller
     * supplyToken - The supplied token to platform in existing position
     * withdrawAmount - Amount of supplyToken to redeem and transferTo accountOwner
     * maxRedeemAmount - Decrease position by redeeming at most this amount of supplied token. Can be greater than supplied amount to support zero dust withdrawals
     * borrowToken - The borrowed token from platform in existing position
     * minRepayAmount - Repay debt of at least this amount of borrowToken or revert. Used to protect from unwanted slippage
     * exchangeData - ABI encoded (bytes1, address[]), for (getExchangerAdapter, swapPath). Required for swapping supplyToken to borrowToken, when not same token
     */
    function decreaseSimplePositionWithLoop(
        address platform,
        address supplyToken,
        uint256 withdrawAmount,
        uint256 maxRedeemAmount,
        address borrowToken,
        uint256 minRepayAmount,
        bytes memory exchangeData
    ) external;
}
