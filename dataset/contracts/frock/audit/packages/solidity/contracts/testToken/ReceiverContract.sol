// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ReceiverContract {
    bytes4 internal constant _INTERFACE_ID_ERC1363_RECEIVER = 0x88a7ca5c;

    function onTransferReceived(
        address operator,
        address from,
        uint256 value,
        bytes memory data
    ) external returns (bytes4) {     
        
        return _INTERFACE_ID_ERC1363_RECEIVER;
    }
}