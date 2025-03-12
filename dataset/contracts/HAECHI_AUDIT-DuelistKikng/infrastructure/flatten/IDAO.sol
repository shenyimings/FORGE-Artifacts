// Root file: contracts/interfaces/IDAO.sol

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IDAO {
  struct Proposal {
    bytes32 proposalDigest;
    int256 vote;
    uint64 expired;
    bool executed;
    bool delegate;
    address target;
    bytes data;
  }

  function init(address _registry, bytes32 _domain) external returns (bool);

  function createProposal(Proposal memory newProposal) external returns (uint256);

  function voteProposal(uint256 proposalId, bool positive) external returns (bool);

  function execute(uint256 proposalId) external returns (bool);
}
