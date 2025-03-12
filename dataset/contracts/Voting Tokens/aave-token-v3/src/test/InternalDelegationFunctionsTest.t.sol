// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {AaveTokenV3} from '../AaveTokenV3.sol';
import {DelegationMode} from '../DelegationAwareBalance.sol';

import {AaveUtils, console} from './utils/AaveUtils.sol';

contract StorageTest is AaveTokenV3, AaveUtils {
  function setUp() public {}

  function testFor_getDelegatedPowerByType() public {
    DelegationState memory userState;
    userState.delegatedPropositionBalance = 100;
    userState.delegatedVotingBalance = 200;
    assertEq(
      _getDelegatedPowerByType(userState, GovernancePowerType.VOTING),
      userState.delegatedVotingBalance * POWER_SCALE_FACTOR
    );
    assertEq(
      _getDelegatedPowerByType(userState, GovernancePowerType.PROPOSITION),
      userState.delegatedPropositionBalance * POWER_SCALE_FACTOR
    );
  }

  function testFor_getDelegateeByType() public {
    address user = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    DelegationState memory userState;

    _votingDelegatee[user] = address(user2);
    _propositionDelegatee[user] = address(user3);

    userState.delegationMode = DelegationMode.VOTING_DELEGATED;
    assertEq(_getDelegateeByType(user, userState, GovernancePowerType.VOTING), user2);
    assertEq(_getDelegateeByType(user, userState, GovernancePowerType.PROPOSITION), address(0));

    userState.delegationMode = DelegationMode.PROPOSITION_DELEGATED;
    assertEq(_getDelegateeByType(user, userState, GovernancePowerType.VOTING), address(0));
    assertEq(_getDelegateeByType(user, userState, GovernancePowerType.PROPOSITION), user3);

    userState.delegationMode = DelegationMode.FULL_POWER_DELEGATED;
    assertEq(_getDelegateeByType(user, userState, GovernancePowerType.VOTING), user2);
    assertEq(_getDelegateeByType(user, userState, GovernancePowerType.PROPOSITION), user3);
  }

  function _setDelegationModeAndTest(
    DelegationMode initialState,
    GovernancePowerType governancePowerType,
    bool willDelegate,
    DelegationMode expectedState
  ) internal {
    DelegationState memory userState;
    DelegationState memory updatedUserState;
    userState.delegationMode = initialState;
    updatedUserState = _updateDelegationModeByType(userState, governancePowerType, willDelegate);
    assertTrue(
      updatedUserState.delegationMode == expectedState,
      Strings.toString(uint8(updatedUserState.delegationMode))
    );
  }

  function testFor_updateDelegationModeByType() public {
    _setDelegationModeAndTest(
      DelegationMode.NO_DELEGATION,
      GovernancePowerType.VOTING,
      true,
      DelegationMode.VOTING_DELEGATED
    );
    _setDelegationModeAndTest(
      DelegationMode.NO_DELEGATION,
      GovernancePowerType.VOTING,
      false,
      DelegationMode.NO_DELEGATION
    );
    _setDelegationModeAndTest(
      DelegationMode.VOTING_DELEGATED,
      GovernancePowerType.VOTING,
      true,
      DelegationMode.VOTING_DELEGATED
    );
    _setDelegationModeAndTest(
      DelegationMode.FULL_POWER_DELEGATED,
      GovernancePowerType.VOTING,
      false,
      DelegationMode.PROPOSITION_DELEGATED
    );
    _setDelegationModeAndTest(
      DelegationMode.NO_DELEGATION,
      GovernancePowerType.PROPOSITION,
      true,
      DelegationMode.PROPOSITION_DELEGATED
    );
    _setDelegationModeAndTest(
      DelegationMode.PROPOSITION_DELEGATED,
      GovernancePowerType.PROPOSITION,
      false,
      DelegationMode.NO_DELEGATION
    );
    _setDelegationModeAndTest(
      DelegationMode.PROPOSITION_DELEGATED,
      GovernancePowerType.VOTING,
      true,
      DelegationMode.FULL_POWER_DELEGATED
    );
    _setDelegationModeAndTest(
      DelegationMode.FULL_POWER_DELEGATED,
      GovernancePowerType.VOTING,
      true,
      DelegationMode.FULL_POWER_DELEGATED
    );
    _setDelegationModeAndTest(
      DelegationMode.VOTING_DELEGATED,
      GovernancePowerType.PROPOSITION,
      true,
      DelegationMode.FULL_POWER_DELEGATED
    );
    _setDelegationModeAndTest(
      DelegationMode.FULL_POWER_DELEGATED,
      GovernancePowerType.PROPOSITION,
      true,
      DelegationMode.FULL_POWER_DELEGATED
    );
  }
}
