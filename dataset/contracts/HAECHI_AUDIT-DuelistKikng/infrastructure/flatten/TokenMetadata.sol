// Root file: contracts/libraries/TokenMetadata.sol

// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;

abstract contract TokenMetadata {
  // Metadata for DAO token initialization
  struct Metadata {
    string symbol;
    string name;
    address genesis;
    address grandDAO;
  }
}
