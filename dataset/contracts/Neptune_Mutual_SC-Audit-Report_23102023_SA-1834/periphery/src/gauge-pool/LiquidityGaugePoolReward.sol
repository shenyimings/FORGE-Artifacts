// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "./LiquidityGaugePoolController.sol";
import "../escrow/interfaces/IVoteEscrowToken.sol";

abstract contract LiquidityGaugePoolReward is LiquidityGaugePoolController {
  function _denominator() internal pure returns (uint256) {
    return 10_000;
  }

  function _getEpochEndTimestamp() private view returns (uint256) {
    return block.timestamp < _epochEndTimestamp ? block.timestamp : _epochEndTimestamp;
  }

  function _getRewardPerTokenUnit() private view returns (uint256) {
    if (_lockedByEveryone == 0) {
      return _rewardPerTokenUnit;
    }

    uint256 epochEnd = _getEpochEndTimestamp();
    uint256 totalWeight = _lockedByEveryone + ((_totalVotingPower * _poolInfo.veBoostRatio) / _denominator());

    return _rewardPerTokenUnit + ((epochEnd - _lastRewardTimestamp) * _rewardPerSecond * 1e18) / totalWeight;
  }

  function _getPendingRewards(address account) internal view returns (uint256) {
    uint256 pending = _pendingRewardToDistribute[account];
    uint256 myWeight = _lockedByMe[account] + ((_myVotingPower[account] * _poolInfo.veBoostRatio) / _denominator());

    return pending + ((myWeight * (_getRewardPerTokenUnit() - _lastRewardPerTokenUnit[account])) / 1e18);
  }

  function _updateReward(address account) internal {
    _rewardPerTokenUnit = _getRewardPerTokenUnit();
    _lastRewardTimestamp = _getEpochEndTimestamp();

    if (account != address(0)) {
      _pendingRewardToDistribute[account] = _getPendingRewards(account);
      _lastRewardPerTokenUnit[account] = _rewardPerTokenUnit;
    }

    _updateVotingPowers();
  }

  function _updateVotingPowers() private {
    uint256 previous = _myVotingPower[_msgSender()];
    uint256 previousTotal = _totalVotingPower;

    uint256 current = IVoteEscrowToken(_poolInfo.veToken).getVotingPower(_msgSender());

    _totalVotingPower = _totalVotingPower + current - previous;
    _myVotingPower[_msgSender()] = current;

    emit VotingPowersUpdated(_poolInfo.key, _msgSender(), previous, current, previousTotal, _totalVotingPower);
  }
}
