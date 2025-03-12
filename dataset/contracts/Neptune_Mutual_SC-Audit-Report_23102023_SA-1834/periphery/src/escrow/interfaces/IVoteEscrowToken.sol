// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IVoteEscrowLocker.sol";
import "../../util/interfaces/IThrowable.sol";

interface IVoteEscrowToken is IThrowable, IERC20Upgradeable, IVoteEscrowLocker {
  function lock(uint256 amount, uint256 durationInWeeks) external;
  function unlock() external;
  function unlockPrematurely() external;

  function calculateBoost(uint256 duration) external pure returns (uint256);
  function getVotingPower(address account) external view returns (uint256);

  error VoteEscrowUnlockError(uint256 unlocksAt);
  error VoteEscrowAlreadyUnlockedError();
  error VoteEscrowUnlockOffsetError(uint256 height);
}
