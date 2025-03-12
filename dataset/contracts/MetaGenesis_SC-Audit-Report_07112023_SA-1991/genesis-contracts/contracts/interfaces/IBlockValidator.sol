// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IBlockValidator {
    struct BlockPayload {
        address coinbase;
        bytes32 blockHash;
        uint256 blockReward;
        bool isFinalized;
    }

    function blockPayloads(
        uint256 blockNumber
    ) external returns (BlockPayload memory);

    function finalizeBlock(uint256 blockNumber) external;
}
