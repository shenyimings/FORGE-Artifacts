// SPDX-License-Identifier: MIT

/**

  This is an extension of the AaveTokenV3 with added getters on the _balances fields

 */

pragma solidity ^0.8.0;

import {AaveTokenV3} from '../munged/src/AaveTokenV3.sol';
import {DelegationMode} from '../munged/src/DelegationAwareBalance.sol';

contract AaveTokenV3Harness is AaveTokenV3 {
  // returns user's token balance, used in some community rules
  function getBalance(address user) public view returns (uint104) {
    return _balances[user].balance;
  }

  // returns user's delegated proposition balance
  function getDelegatedPropositionBalance(address user) public view returns (uint72) {
    return _balances[user].delegatedPropositionBalance;
  }

  // returns user's delegated voting balance
  function getDelegatedVotingBalance(address user) public view returns (uint72) {
    return _balances[user].delegatedVotingBalance;
  }

  //returns user's delegating proposition status
  function getDelegatingProposition(address user) public view returns (bool) {
    return
      _balances[user].delegationMode == DelegationMode.PROPOSITION_DELEGATED ||
      _balances[user].delegationMode == DelegationMode.FULL_POWER_DELEGATED;
  }

  // returns user's delegating voting status
  function getDelegatingVoting(address user) public view returns (bool) {
    return
      _balances[user].delegationMode == DelegationMode.VOTING_DELEGATED ||
      _balances[user].delegationMode == DelegationMode.FULL_POWER_DELEGATED;
  }

  // returns user's voting delegate
  function getVotingDelegatee(address user) public view returns (address) {
      //return _getDelegateeByType(user, _getDelegationState(user), GovernancePowerType.VOTING);
      return _votingDelegatee[user];
  }

  // returns user's proposition delegate
  function getPropositionDelegatee(address user) public view returns (address) {
    return _propositionDelegatee[user];
  }

  // returns user's delegation state
  function getDelegationMode(address user) public view returns (DelegationMode) {
    return _balances[user].delegationMode;
  }

  function getDelegatedPowerVoting(address user) public view returns (uint256) {
      DelegationState memory userState = _getDelegationState(user);
      uint256 userDelegatedPower = _getDelegatedPowerByType(userState, GovernancePowerType.VOTING);
      
      return userDelegatedPower;
  }
}
