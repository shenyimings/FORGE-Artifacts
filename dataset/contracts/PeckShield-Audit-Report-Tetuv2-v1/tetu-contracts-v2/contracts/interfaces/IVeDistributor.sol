// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IVeDistributor {

  function rewardToken() external view returns (address);

  function checkpoint() external;

  function checkpointTotalSupply() external;

  function claim(uint _tokenId) external returns (uint);

}
