// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface ILockedTokenOffer {
    function lockedTokenAddress() external view returns (address);
    function amountWanted() external view returns (uint256);
    function totalLockedToken() external view returns (uint256);
    function tokenWanted() external view returns (address);
}
