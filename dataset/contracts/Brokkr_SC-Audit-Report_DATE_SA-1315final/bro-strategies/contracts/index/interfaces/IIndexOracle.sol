// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IIndexOracle {
    function decimals() external pure returns (uint8);

    function getPrice(
        address token,
        bool maximize,
        bool includeAmmPrice
    ) external view returns (uint256 price);

    function getPrices(
        address[] calldata tokens,
        bool maximize,
        bool includeAmmPrice
    ) external view returns (uint256[] calldata prices);

    function setPriceFeed(address token, address priceFeed) external;
}
