// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

struct SimplePositionMetadata {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 collateralUsageFactor;
    uint256 principalValue;
    uint256 positionValue;
    address positionAddress;
    address platformAddress;
    address supplyTokenAddress;
    address borrowTokenAddress;
}

interface ISimplePositionBaseConnector {
    function getBorrowBalance() external returns (uint256);

    function getSupplyBalance() external returns (uint256);

    function getPositionValue() external returns (uint256);

    function getPrincipalValue() external returns (uint256);

    function getCollateralUsageFactor() external returns (uint256);

    function getSimplePositionDetails()
        external
        view
        returns (
            address,
            address,
            address
        );

    function getPositionMetadata() external returns (SimplePositionMetadata memory);
}
