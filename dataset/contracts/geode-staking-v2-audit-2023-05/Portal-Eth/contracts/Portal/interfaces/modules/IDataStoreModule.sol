// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IDataStoreModule {
  function generateId(string calldata _name, uint256 _type) external pure returns (uint256 id);

  function getKey(uint256 _id, bytes32 _param) external pure returns (bytes32 key);

  function allIdsByType(uint256 _type, uint256 _index) external view returns (uint256);

  function allIdsByTypeLength(uint256 _type) external view returns (uint256);

  function readUint(uint256 id, bytes32 key) external view returns (uint256 data);

  function readAddress(uint256 id, bytes32 key) external view returns (address data);

  function readBytes(uint256 id, bytes32 key) external view returns (bytes memory data);

  function readUintArray(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view returns (uint256 data);

  function readBytesArray(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view returns (bytes memory data);

  function readAddressArray(
    uint256 id,
    bytes32 key,
    uint256 index
  ) external view returns (address data);
}
