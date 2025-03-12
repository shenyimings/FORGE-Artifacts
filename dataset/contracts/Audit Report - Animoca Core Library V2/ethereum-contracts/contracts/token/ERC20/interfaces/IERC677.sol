// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title ERC677 transferAndCall Token Standard, basic interface.
/// @dev See https://github.com/ethereum/EIPs/issues/677
interface IERC677 {
    function transferAndCall(address receiver, uint256 amount, bytes calldata data) external returns (bool success);
}
