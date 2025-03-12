// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { CloneFactory } from "./CloneFactory.sol";
import { MerkleAirdrop } from "./MerkleAirdrop.sol";

contract MerkleAirdropGateway {
  function bulkClaim(
    address[] calldata merkleAirdrops,
    uint256[] calldata indices,
    address[] calldata accounts,
    uint256[] calldata amounts,
    bytes32[][] calldata merkleProof
  ) external {
    for (uint256 i = 0; i < merkleAirdrops.length; ) {
      MerkleAirdrop(merkleAirdrops[i]).claim(
        indices[i],
        accounts[i],
        amounts[i],
        merkleProof[i]
      );
      unchecked {
        i++;
      }
    }
  }
}
