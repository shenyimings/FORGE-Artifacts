// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IVaultPriceFeed {
    function setTokenConfig(address _token, address _priceFeed, uint256 _priceDecimals) external;

    function getLastPrice(address _token) external view returns (uint256);
}
