// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMintCallback {
    function mintCallback(uint256 amountOwed, bytes calldata data) external;
}
