// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

/// @title EtherRejector
/// @author info@lido.fi
/// @notice a test contract that rejects any incoming ether
contract EtherRejector {
    /// @notice rejects any ether
    /// @dev test ether transfer fails
    fallback() external payable {
        revert("REJECTED");
    }
}
