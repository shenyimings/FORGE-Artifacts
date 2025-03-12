// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MockWormholeTokenBridge {
    event WormholeTransfer(address indexed token, uint256 amount, uint16 indexed recipientChain, bytes32 indexed recipient, uint256 arbiterFee, uint32 nonce);

    function transferTokens(address token, uint256 amount, uint16 recipientChain, bytes32 recipient, uint256 arbiterFee, uint32 nonce) public payable returns (uint64 sequence) {
        emit WormholeTransfer(token, amount, recipientChain, recipient, arbiterFee, nonce);

        sequence = 0xFFFFFFFFFFFFFFFF;
    }
}
