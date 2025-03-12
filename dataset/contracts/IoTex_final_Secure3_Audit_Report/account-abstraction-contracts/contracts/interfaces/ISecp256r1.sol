// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISecp256r1 {
    function validateSignature(
        bytes32 message,
        bytes calldata signature,
        bytes calldata publicKey
    ) external view returns (bool);
}
