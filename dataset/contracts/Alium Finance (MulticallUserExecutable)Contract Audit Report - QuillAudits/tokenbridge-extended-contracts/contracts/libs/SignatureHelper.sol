// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library SignatureHelper {
    function getSignature(bytes memory _data)
        internal
        pure
        returns (bytes4 signature)
    {
        assembly {
            signature := mload(add(_data, 32))
        }
    }

    function getHash(bytes4[] memory _signatures)
        internal
        pure
        returns (bytes32 hash)
    {
        hash = keccak256(abi.encodePacked(_signatures));
    }
}
