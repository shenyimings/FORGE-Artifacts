// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IVoter {

  function ve() external view returns (address);

  function attachTokenToGauge(address stakingToken, uint _tokenId, address account) external;

  function detachTokenFromGauge(address stakingToken, uint _tokenId, address account) external;

  function distribute(address stakingToken) external;

  function notifyRewardAmount(uint amount) external;

  function detachTokenFromAll(uint tokenId, address account) external;

}
