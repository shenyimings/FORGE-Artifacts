// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

function addressToUint256(address a) pure returns (uint256) {
    return uint256(uint160(a));
}

function addressToSalt(address a) pure returns (bytes32) {
    return bytes32(uint256(uint160(a)));
}