// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Errors {
    error ArrayEmpty();
    error InsufficientBalance(uint256 balance, uint256 required);
    // cross chain
    error InsufficientFeeToSendMsg(uint256 currentFee, uint256 requiredFee);
    error OnlyLayerZeroEndpoint();
    error MsgNotFromReceiveEndpoint(address sender);
    error OnlyWhitelisted();
}
