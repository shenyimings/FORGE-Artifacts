// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IItemOffer {
    function itemAddress() external view returns (address);
    function priceWanted() external view returns (uint256);
    function totalItems() external view returns (uint256);
    function tokenWanted() external view returns (address);
}
