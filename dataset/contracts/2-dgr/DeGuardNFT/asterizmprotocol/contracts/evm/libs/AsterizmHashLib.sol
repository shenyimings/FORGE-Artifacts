// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library AsterizmHashLib {

    /// Build asterizm simple hash (used for transfer within same network types)
    /// @param _packed bytes
    /// @return bytes32
    function buildSimpleHash(bytes memory _packed) internal pure returns(bytes32) {
        return sha256(_packed);
    }

    /// Build asterizm crosschain hash (used for transfer within different network types)
    /// @param _packed bytes
    /// @return bytes32
    function buildCrosschainHash(bytes memory _packed) internal pure returns(bytes32) {
        bytes memory staticChunk = new bytes(112);
        for (uint i = 0; i < 112; i++) {
            staticChunk[i] = bytes(_packed)[i];
        }

        bytes memory payloadChunk = new bytes(_packed.length - staticChunk.length);
        for (uint i = staticChunk.length; i < _packed.length; i++) {
            payloadChunk[i - staticChunk.length] = bytes(_packed)[i];
        }

        uint length = payloadChunk.length;
        uint8 chunkLength = 127;

        bytes32 hash = sha256(staticChunk);

        for (uint i = 0; i <= length / chunkLength; i++) {
            uint from = chunkLength * i;
            uint to = from + chunkLength <= length ? from + chunkLength : length;
            bytes memory chunk = new bytes(to - from);
            for(uint j = from; j < to; j++){
                chunk[j - from] = bytes(payloadChunk)[j];
            }

            hash = sha256(abi.encode(hash, sha256(chunk)));
        }

        return hash;
    }
}
