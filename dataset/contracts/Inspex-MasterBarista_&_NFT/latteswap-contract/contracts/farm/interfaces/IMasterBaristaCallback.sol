// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IMasterBaristaCallback {
  function masterBaristaCall(
    address stakeToken,
    address userAddr,
    uint256 unboostedReward
  ) external;
}
