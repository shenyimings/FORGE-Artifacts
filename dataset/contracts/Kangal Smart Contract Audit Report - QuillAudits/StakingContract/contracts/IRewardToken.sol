//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

interface IRewardToken {
  function giveMintingConsent() external;

  function removeMintingConsent() external;

  function proposeMinter(address proposedMinterAddress) external;

  function approveProposedMinter(address proposedMinterAddress) external;

  function proposeMinterRemoval(address minterAddress) external;

  function approveMinterRemoval(address minterAddress) external;

  function mint(address to, uint256 amount) external;
}
