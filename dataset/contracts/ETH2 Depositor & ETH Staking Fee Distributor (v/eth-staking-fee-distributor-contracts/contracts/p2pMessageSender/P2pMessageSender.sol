// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
* @title Contract for passing data to event log
*/
contract P2pMessageSender {
    /**
    * @notice Emits on each data piece
    * @param sender message sender
    * @param hash hashed text for faster lookup
    * @param text full text value
    */
    event Message(address indexed sender, string indexed hash, string text);

    /**
    * @notice Pass text to event log.
    * @param text text to be passed
    */
    function send(string calldata text) external {
        emit Message(msg.sender, text, text);
    }
}
