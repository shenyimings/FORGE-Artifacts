// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

interface IBridge {
    function queuedTransactions(bytes32 txHash) external view returns (bool);

    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) external returns (bytes32);

    function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) external;

    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) external payable returns (bytes memory);
}
