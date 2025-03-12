// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IElemonMarketplace{
    function setElemonNftAddress(address newAddress) external;
    function setElemonTokenAddress(address newAddress) external;
    function setFeePercent(uint feePercent) external;
}