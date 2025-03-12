// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IStaking } from "../staking/interfaces/IStaking.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { PLP } from "../tokens/PLP.sol";

// Universal setting for lockdrop last for 4 days where
// 1. Deposit period last for 4 days
// 2. First 3 days is 100% withdrawable
// 3. Withdraw day 4: First 12 hours 50 % withdrawable
// 4. Withdraw day 4: After 12 hours dacaying withdraw from 50% to 0%
// 5. On day 4, user can only withdraw once

contract LockdropConfig is OwnableUpgradeable {
  // --- States ---
  IStaking public plpStaking;
  IERC20Upgradeable public p88Token;
  IERC20Upgradeable public plpToken;
  address public gatewayAddress;
  address public lockdropCompounderAddress;
  uint256 public startLockTimestamp; // timestamp for starting lockdrop event
  uint256 public endLockTimestamp; // timestamp for deposit period after start lockdrop event
  uint256 public startDecayingWithdrawalTimestamp;
  uint256 public startRestrictedWithdrawalTimestamp; // timestamp for withdraw period after start lockdrop event
  uint256 public decayStartPercentage;
  uint256 public startTimeDecay;

  function initialize(
    uint256 startLockTimestamp_,
    IStaking plpStaking_,
    IERC20Upgradeable plpToken_,
    IERC20Upgradeable p88Token_,
    address gatewayAddress_,
    address lockdropCompounder_
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    decayStartPercentage = 50;
    startTimeDecay = 12 hours;
    plpStaking = plpStaking_;
    startLockTimestamp = startLockTimestamp_;
    endLockTimestamp = startLockTimestamp_ + (4 days);
    startRestrictedWithdrawalTimestamp = startLockTimestamp_ + 3 days;
    startDecayingWithdrawalTimestamp =
      startLockTimestamp_ +
      3 days +
      startTimeDecay;
    plpToken = plpToken_;
    p88Token = p88Token_;
    gatewayAddress = gatewayAddress_;
    lockdropCompounderAddress = lockdropCompounder_;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
