// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IDerivedToken} from '../../../interfaces/IDerivedToken.sol';
import {IRewardedToken} from '../../../interfaces/IRewardedToken.sol';
import {IEmergencyAccess} from '../../../interfaces/IEmergencyAccess.sol';

interface IStakeToken is IDerivedToken, IRewardedToken {
  function stake(
    address to,
    uint256 underlyingAmount,
    uint256 referral
  ) external returns (uint256 stakeAmount);

  function redeem(address to, uint256 maxStakeAmount) external returns (uint256 stakeAmount);

  function redeemUnderlying(address to, uint256 maxUnderlyingAmount)
    external
    returns (uint256 underlyingAmount);

  function cooldown() external;

  function getCooldown(address) external view returns (uint32);

  function exchangeRate() external view returns (uint256);

  function isRedeemable() external view returns (bool);

  function balanceAndCooldownOf(address holder)
    external
    view
    returns (
      uint256 balance,
      uint32 windowStart,
      uint32 windowEnd
    );
}

interface IManagedStakeToken is IEmergencyAccess {
  function setRedeemable(bool redeemable) external;

  function getMaxSlashablePercentage() external view returns (uint16);

  function setMaxSlashablePercentage(uint16 percentage) external;

  function setCooldown(uint32 cooldownPeriod, uint32 unstakePeriod) external;

  function slashUnderlying(
    address destination,
    uint256 minAmount,
    uint256 maxAmount
  ) external returns (uint256);
}
