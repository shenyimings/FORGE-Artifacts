// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

/// @title Destructable
/// @author info@lido.fi
/// @notice a test contract for transferring ether to non-payable contracts
contract Destructable {

    /// @notice destroys the contact and forwards ether to another addres
    /// @dev force ether onto another non-payable contract
    /// @param _heir address to forward ether to
    function die(address _heir) public payable {
        selfdestruct(payable(_heir));
    }
}
