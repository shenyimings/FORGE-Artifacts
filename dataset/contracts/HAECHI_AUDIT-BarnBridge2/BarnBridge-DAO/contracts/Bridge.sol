// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.1;

import "./Parameters.sol";

abstract contract Bridge is Parameters {

    mapping(bytes32 => bool) public queuedTransactions;

    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) internal returns (bytes32) {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);
        queuedTransactions[txHash] = true;

        return txHash;
    }

    function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) internal {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);
        queuedTransactions[txHash] = false;
    }

    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) internal returns (bytes memory) {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);

        require(block.timestamp >= eta, "executeTransaction: Transaction hasn't surpassed time lock.");
        require(block.timestamp <= eta + gracePeriodDuration, "executeTransaction: Transaction is stale.");

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value : value}(callData);
        require(success, string(returnData));

        return returnData;
    }

    function _getTxHash(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) internal returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }
}
