// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '../libraries/RegistryUser.sol';
import '../libraries/Bytes.sol';
import '../interfaces/IRNGConsumer.sol';

/**
 * Random Number Generator
 * Name: RNG
 * Domain: Infrastructure
 */
contract RNG is RegistryUser {
  // Use bytes lib for bytes
  using Bytes for bytes;

  // Commit scheme data
  struct CommitSchemeData {
    uint256 index;
    bytes32 digest;
    bytes32 secret;
  }

  // Commit scheme progess
  struct CommitSchemeProgress {
    uint256 remaining;
    uint256 total;
  }

  // Total committed digest
  uint256 private totalDigest;

  uint256 private remainingDigest;

  // Secret digests map
  mapping(uint256 => bytes32) private secretDigests;

  // Reverted digiest map
  mapping(bytes32 => uint256) private digestIndexs;

  // Secret storage
  mapping(uint256 => bytes32) private secretValues;

  // Commit event
  event Committed(uint256 indexed index, bytes32 indexed digest);

  // Reveal event
  event Revealed(uint256 indexed index, uint256 indexed s, uint256 indexed t);

  // Pass constructor parameter to User
  constructor(address registry_, bytes32 domain_) {
    _registryUserInit(registry_, domain_);
  }

  /*******************************************************
   * Oracle section
   ********************************************************/

  // DKDAO Oracle will commit H(S||t) to blockchain
  function commit(bytes32 digest) external onlyAllowSameDomain('Oracle') returns (uint256) {
    return _commit(digest);
  }

  // Allow Oracle to commit multiple values to blockchain
  function batchCommit(bytes calldata digest) external onlyAllowSameDomain('Oracle') returns (bool) {
    bytes32[] memory digestList = digest.toBytes32Array();
    for (uint256 i = 0; i < digestList.length; i += 1) {
      require(_commit(digestList[i]) > 0, 'RNG: Unable to add digest to blockchain');
    }
    return true;
  }

  // DKDAO Oracle will reveal S and t
  function reveal(bytes memory data) external onlyAllowSameDomain('Oracle') returns (uint256) {
    require(data.length >= 84, 'RNG: Input data has wrong format');
    address target = data.readAddress(0);
    uint256 index = data.readUint256(20);
    uint256 secret = data.readUint256(52);
    uint256 s;
    uint256 t;
    remainingDigest -= 1;
    t = secret & 0xffffffffffffffff;
    s = secret >> 64;
    // Make sure that this secret is valid
    require(secretValues[index] == bytes32(''), 'Rng: This secret was revealed');
    require(keccak256(abi.encodePacked(secret)) == secretDigests[index], "Rng: Secret doesn't match digest");
    secretValues[index] = bytes32(secret);
    // Increase last reveal value
    // Hook call to fair distribution
    if (target != address(0x00)) {
      require(
        IRNGConsumer(target).compute(data.readBytes(52, data.length - 52)),
        "RNG: Can't do callback to distributor"
      );
    }
    emit Revealed(index, s, t);
    return index;
  }

  /*******************************************************
   * Private section
   ********************************************************/

  // Commit digest to blockchain state
  function _commit(bytes32 digest) private returns (uint256) {
    // We begin from 1 instead of 0 to prevent error
    totalDigest += 1;
    remainingDigest += 1;
    secretDigests[totalDigest] = digest;
    digestIndexs[digest] = totalDigest;
    emit Committed(totalDigest, digest);
    return totalDigest;
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Get progress of commit scheme
  function getDataByIndex(uint256 index) external view returns (CommitSchemeData memory) {
    return CommitSchemeData({ index: index, digest: secretDigests[index], secret: secretValues[index] });
  }

  // Get progress of commit scheme
  function getDataByDigest(bytes32 digest) external view returns (CommitSchemeData memory) {
    uint256 index = digestIndexs[digest];
    return CommitSchemeData({ index: index, digest: secretDigests[index], secret: secretValues[index] });
  }

  // Get progress of commit scheme
  function getProgress() external view returns (CommitSchemeProgress memory) {
    return CommitSchemeProgress({ remaining: remainingDigest, total: totalDigest });
  }
}
