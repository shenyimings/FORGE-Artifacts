// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

interface IWormhole {
  event LogTokensLocked(
    uint8 target_chain,
    uint8 token_chain,
    uint8 token_decimals,
    bytes32 indexed token,
    bytes32 indexed sender,
    bytes32 recipient,
    uint256 amount,
    uint32 nonce
  );

  struct ParsedVAA {
    uint8 version;
    bytes32 hash;
    uint32 guardian_set_index;
    uint32 timestamp;
    uint8 action;
    bytes payload;
  }

  function lockAssets(
    address asset,
    uint256 amount,
    bytes32 recipient,
    uint8 target_chain,
    uint32 nonce,
    bool refund_dust
  ) external;

  function lockETH(
    bytes32 recipient,
    uint8 target_chain,
    uint32 nonce
  ) external payable;
}
