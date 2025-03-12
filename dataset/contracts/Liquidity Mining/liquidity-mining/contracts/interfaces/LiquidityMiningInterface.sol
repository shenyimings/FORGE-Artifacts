// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @dev LiquidityMiningInterface is for comptroller
interface LiquidityMiningInterface {
    function updateSupplyIndex(address cToken, address[] memory accounts) external;
    function updateBorrowIndex(address cToken, address[] memory accounts) external;
}
