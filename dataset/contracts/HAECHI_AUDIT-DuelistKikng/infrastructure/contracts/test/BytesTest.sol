// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '../libraries/Bytes.sol';

contract BytesTest {
  using Bytes for bytes;

  function getBytesToBytes32Array(bytes memory input) external pure returns (bytes32[] memory) {
    return input.toBytes32Array();
  }

  function getAddress(bytes memory input, uint256 offset) external pure returns (address) {
    return input.readAddress(offset);
  }

  function getUint256(bytes memory input, uint256 offset) external pure returns (uint256) {
    return input.readUint256(offset);
  }

  function getBytes(
    bytes memory input,
    uint256 offset,
    uint256 length
  ) external pure returns (bytes memory) {
    return input.readBytes(offset, length);
  }
}
