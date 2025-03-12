// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "../../dependencies/ABDKMath64x64.sol";
import "./FakeVoteEscrowLockerV2.sol";

abstract contract FakeVoteEscrowBoosterV2 is FakeVoteEscrowLockerV2 {
  using ABDKMath64x64 for uint256;
  using ABDKMath64x64 for int128;

  function _denominator() internal pure returns (uint256) {
    return 10_000;
  }

  function _calculateBoost(uint256 duration) internal pure returns (uint256) {
    uint256 _BOOST_FLOOR = 10_000;
    uint256 _BOOST_CEILING = 40_000;

    if (duration > 1456 days) {
      return _BOOST_CEILING;
    }

    uint256 result = duration.divu(1 days).div(uint256(1456).fromUInt()).mul(_BOOST_CEILING.divu(_denominator()).log_2()).exp_2().mulu(_denominator());

    if (result < _BOOST_FLOOR) {
      return _BOOST_FLOOR;
    }

    if (result > _BOOST_CEILING) {
      return _BOOST_CEILING;
    }

    return result;
  }

  function _getVotingPower(uint256 balance, uint256 unlockTimestamp, uint256 currentTimestamp) internal pure returns (uint256) {
    if (unlockTimestamp <= currentTimestamp) {
      return balance;
    }

    return (balance * _calculateBoost(unlockTimestamp - currentTimestamp)) / _denominator();
  }
}
