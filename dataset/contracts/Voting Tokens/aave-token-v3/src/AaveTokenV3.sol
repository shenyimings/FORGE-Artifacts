// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseAaveTokenV2} from './BaseAaveTokenV2.sol';
import {BaseDelegation} from './BaseDelegation.sol';

contract AaveTokenV3 is BaseAaveTokenV2, BaseDelegation {
  /**
   * @dev initializes the contract upon assignment to the InitializableAdminUpgradeabilityProxy
   */
  function initialize() external virtual initializer {}

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 fromBalanceBefore,
    uint256 toBalanceBefore,
    uint256 amount
  ) internal override {
    _delegationChangeOnTransfer(from, to, fromBalanceBefore, toBalanceBefore, amount);
  }

  function _getDelegationState(address user)
    internal
    view
    override
    returns (DelegationState memory)
  {
    DelegationAwareBalance memory userState = _balances[user];
    return
      DelegationState({
        delegatedPropositionBalance: userState.delegatedPropositionBalance,
        delegatedVotingBalance: userState.delegatedVotingBalance,
        delegationMode: userState.delegationMode
      });
  }

  function _getBalance(address user) internal view override returns (uint256) {
    return _balances[user].balance;
  }

  function _setDelegationState(address user, DelegationState memory delegationState)
    internal
    override
  {
    DelegationAwareBalance storage userState = _balances[user];
    userState.delegatedPropositionBalance = delegationState.delegatedPropositionBalance;
    userState.delegatedVotingBalance = delegationState.delegatedVotingBalance;
    userState.delegationMode = delegationState.delegationMode;
  }

  function _incrementNonces(address user) internal override returns (uint256) {
    unchecked {
      // Does not make sense to check because it's not realistic to reach uint256.max in nonce
      return _nonces[user]++;
    }
  }

  function _getDomainSeparator() internal view override returns (bytes32) {
    return DOMAIN_SEPARATOR();
  }
}
