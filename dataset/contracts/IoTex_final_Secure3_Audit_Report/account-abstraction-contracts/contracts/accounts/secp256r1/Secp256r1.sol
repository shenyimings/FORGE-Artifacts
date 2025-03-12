// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/ISecp256r1.sol";

contract Secp256r1 is ISecp256r1 {
    function validateSignature(
        bytes32 message,
        bytes calldata signature,
        bytes calldata publicKey
    ) external view override returns (bool result) {
        bytes32 rs0;
        bytes32 rs1;
        bytes32 Q0;
        bytes32 Q1;

        (rs0, rs1) = abi.decode(signature, (bytes32, bytes32));
        (Q0, Q1) = abi.decode(publicKey, (bytes32, bytes32));

        bytes1 out;
        assembly {
            // free memory pointer
            let input := mload(0x40)

            mstore(input, message)
            mstore(add(input, 0x20), rs0)
            mstore(add(input, 0x40), rs1)
            mstore(add(input, 0x60), "\x04")
            mstore(add(input, 0x61), Q0)
            mstore(add(input, 0x81), Q1)
            let success := staticcall(gas(), 0x8001, input, 0xa1, out, 0x1)
            switch success
            case 0 {
                revert(0x0, 0x0)
            }
            default {
                result := mload(out)
            }
        }
    }
}
