// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title ERC677 transferAndCall Token Standard, receiver interface.
/// @dev See https://github.com/ethereum/EIPs/issues/677
interface IERC677Receiver {
    function onTokenTransfer(address from, uint256 amount, bytes calldata data) external returns (bool success);
}
