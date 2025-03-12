// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IMultiCall {
    struct Call {
        address target;
        bytes callData;
    }

    function getCurrentBlockTimestamp() external view returns (uint256 timestamp);

    function aggregate(Call[] memory calls) external returns (uint256 blockNumber, bytes[] memory returnData);

    function getLastBlockHash() external view returns (bytes32 blockHash);

    function getEthBalance(address addr) external view returns (uint256 balance);

    function getCurrentBlockDifficulty() external view returns (uint256 difficulty);

    function getCurrentBlockGasLimit() external view returns (uint256 gaslimit);

    function getCurrentBlockCoinbase() external view returns (address coinbase);

    function getBlockHash(uint256 blockNumber) external view returns (bytes32 blockHash);
}
