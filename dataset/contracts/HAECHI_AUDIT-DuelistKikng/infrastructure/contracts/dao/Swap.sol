// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '../interfaces/INFT.sol';
import '../libraries/Bytes.sol';
import '../libraries/Verifier.sol';
import '../libraries/RegistryUser.sol';

/**
 * Swap can transfer NFT by consume cryptography proof
 * Name: Swap
 * Domain: Infrastructure
 */
contract Swap is RegistryUser {
  // Verify signature
  using Verifier for bytes;

  // Decode bytes array
  using Bytes for bytes;

  // Partner of duelistking
  mapping(address => bool) private _partners;

  // Nonce
  mapping(address => uint256) private _nonceStorage;

  // List partner
  event ListPartner(address indexed partnerAddress);

  // Delist partner
  event DelistPartner(address indexed partnerAddress);

  // Only allow partner to execute
  modifier onlyPartner() {
    require(_partners[msg.sender] == true, 'Swap: Sender was not partner');
    _;
  }

  // Pass constructor parameter to User
  constructor(address registry_, bytes32 domain_) {
    _registryUserInit(registry_, domain_);
  }

  /*******************************************************
   * Partner section
   ********************************************************/

  // Partners can trigger delegate transfer right with a cyrptography proof from owner
  function delegateTransfer(bytes memory proof) external onlyPartner returns (bool) {
    // Check for size of the proof
    require(proof.length >= 169, 'Swap: Wrong size of the proof, it must be greater than 169 bytes');
    bytes memory signature = proof.readBytes(0, 65);
    bytes memory message = proof.readBytes(65, proof.length - 65);
    address from = message.verifySerialized(signature);
    address to = message.readAddress(0);
    address nft = message.readAddress(20);
    uint256 nonce = message.readUint256(40);
    bytes memory nftTokenIds = message.readBytes(72, proof.length - 72);
    require(nftTokenIds.length % 32 == 0, 'Swap: Invalid token ID length');
    // Transfer one by one
    for (uint256 i = 0; i < nftTokenIds.length; i += 32) {
      INFT(nft).safeTransfer(from, to, nftTokenIds.readUint256(i));
    }
    // Each nonce is only able to be use once
    require(nonce - _nonceStorage[from] == 1, 'Swap: Incorrect nonce of signer');
    _nonceStorage[from] += 1;
    return true;
  }

  /*******************************************************
   * Operator section
   ********************************************************/

  // List a new partner
  function listPartner(address partnerAddress) external onlyAllowSameDomain('Operator') returns (bool) {
    _partners[partnerAddress] = true;
    emit ListPartner(partnerAddress);
    return true;
  }

  // Delist a partner
  function delistPartner(address partnerAddress) external onlyAllowSameDomain('Operator') returns (bool) {
    _partners[partnerAddress] = false;
    emit DelistPartner(partnerAddress);
    return true;
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Get nonce of an address
  function getValidNonce(address owner) external view returns (uint256) {
    return _nonceStorage[owner] + 1;
  }

  // Check an address is partner or not
  function isPartner(address partner) external view returns (bool) {
    return _partners[partner];
  }
}
