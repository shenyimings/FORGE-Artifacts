// SPDX-License-Identifier: MIT

/**

  This is an extension of the AaveTokenV3 with added getters and view function wrappers needed for
  community-written rules
 */

pragma solidity ^0.8.0;

import {AaveTokenV3} from '../../src/AaveTokenV3.sol';
import {DelegationMode} from '../../src/DelegationAwareBalance.sol';
import {ECDSA} from 'openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

contract AaveTokenV3Harness is AaveTokenV3 {
  function getBalance(address user) public view returns (uint104) {
    return _balances[user].balance;
  }

  function getDelegatedPropositionBalance(address user) public view returns (uint72) {
    return _balances[user].delegatedPropositionBalance;
  }

  function getDelegatedVotingBalance(address user) public view returns (uint72) {
    return _balances[user].delegatedVotingBalance;
  }

  function getDelegatingProposition(address user) public view returns (bool) {
    return
      _balances[user].delegationMode == DelegationMode.PROPOSITION_DELEGATED ||
      _balances[user].delegationMode == DelegationMode.FULL_POWER_DELEGATED;
  }

  function getDelegatingVoting(address user) public view returns (bool) {
    return
      _balances[user].delegationMode == DelegationMode.VOTING_DELEGATED ||
      _balances[user].delegationMode == DelegationMode.FULL_POWER_DELEGATED;
  }

  function getVotingDelegatee(address user) public view returns (address) {
    return _votingDelegatee[user];
  }

  function getPropositionDelegatee(address user) public view returns (address) {
    return _propositionDelegatee[user];
  }

  function getDelegationMode(address user) public view returns (DelegationMode) {
    return _balances[user].delegationMode;
  }

  function getNonce(address user) public view returns (uint256) {
    return _nonces[user];
  }

  function ecrecoverWrapper(
    bytes32 hash,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public pure returns (address) {
    return ecrecover(hash, v, r, s);
  }

  function computeMetaDelegateHash(
    address delegator,
    address delegatee,
    uint256 deadline,
    uint256 nonce
  ) public view returns (bytes32) {
      //bytes32 digest = keccak256(
      //abi.encodePacked(
      //'\x19\x01',
      // DOMAIN_SEPARATOR,
       // keccak256(abi.encode(DELEGATE_TYPEHASH, delegator, delegatee, nonce, deadline))
      //)
      //);
    bytes32 digest = ECDSA.toTypedDataHash(
      _getDomainSeparator(),
      keccak256(abi.encode(DELEGATE_TYPEHASH, delegator, delegatee, nonce, deadline))
    );
    return digest;
  }

  function computeMetaDelegateByTypeHash(
    address delegator,
    address delegatee,
    GovernancePowerType delegationType,
    uint256 deadline,
    uint256 nonce
  ) public view returns (bytes32) {
      //    bytes32 digest = keccak256(
      //abi.encodePacked(
      //  '\x19\x01',
      //  DOMAIN_SEPARATOR,
      //  keccak256(
      //  abi.encode(
      //    DELEGATE_BY_TYPE_TYPEHASH,
      //    delegator,
      //    delegatee,
      //    delegationType,
      //    nonce,
      //    deadline
      //  )
      //)
      //)
      //);
    bytes32 digest = ECDSA.toTypedDataHash(
                                           _getDomainSeparator(),
                                           keccak256(
                                                     abi.encode(
                                                                DELEGATE_BY_TYPE_TYPEHASH,
                                                                delegator,
                                                                delegatee,
                                                                delegationType,
                                                                nonce,
                                                                deadline
                                                     )
                                           )
    );
    
    return digest;
  }
}
