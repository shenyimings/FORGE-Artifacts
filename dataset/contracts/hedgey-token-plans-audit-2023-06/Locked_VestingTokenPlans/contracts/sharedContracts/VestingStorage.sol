// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TimelockLibrary.sol';

/// @notice This is the storage contract for the Vesting Plans
/// it contains the logic of the vesting plan object (struct), as well as the events that are utilized and emitted by the contracts

contract VestingStorage {
  /// @dev the Plan is the storage in a struct of the tokens that are currently being vested
  /// @param token is the token address being timelocked
  /// @param amount is the current amount of tokens locked in the vesting plan, both unclaimed vested and unvested tokens. This parameter is updated each time tokens are redeemed, reset to the new remaining unvested and unclaimed amount
  /// @param start is the start date when token vesting begins or began. This parameter gets updated each time tokens are redeemed and claimed, reset to the most recent redeem time
  /// @param cliff is an optional field to add a single cliff date prior to which the tokens cannot be redeemed, this does not change
  /// @param rate is the amount of tokens that vest in a period. This parameter is constand for each plan. 
  /// @param period is the length of time in between each discrete time when tokens vest. If this is set to 1, then tokens unlocke every second. Otherwise the period is longer to allow for interval vesting plans. 
  /// @param vestingAdmin is the adress of the administrator of the plans who can revoke plans at any time prior to them fully vesting. They may also be allowed to transfer plans on behalf of the beneficiary. 
  /// @param adminTransferOBO is a toggle that when true allows a vesting admin to transfer plans on behalf of (OBO) beneficiaries to another wallet. This is really just used for emergencies. 
  struct Plan {
    address token;
    uint256 amount;
    uint256 start;
    uint256 cliff;
    uint256 rate;
    uint256 period;
    address vestingAdmin;
    bool adminTransferOBO;
  }

  /// @dev a mapping of the planId to the Plan struct. This is also mapped of the NFT token ID to the Plan struct, as the planId is the NFT token Id. 
  mapping(uint256 => Plan) public plans;

  ///@notice event emitted when a new vesting plan is created, emits the NFT and planId, as well as all of the info from the plan struct
  event PlanCreated(
    uint256 indexed id,
    address indexed recipient,
    address indexed token,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 end,
    uint256 rate,
    uint256 period,
    address vestingAdmin,
    bool adminTransferOBO
  );

  /// @notice event emitted when a beneficiary redeems some or all of the tokens in their plan. 
  /// It emits the id of the plan, as well as the amount redeemed, any remaining unvested or unclaimed tokens and the date that was the effective new start date, the reset date. 
  event PlanRedeemed(uint256 indexed id, uint256 amountRedeemed, uint256 planRemainder, uint256 resetDate);

  /// @notice event that is emitted when a plan is revoked. emits the plan Id as well as the amount that is vested and redeemed to the beneficiary, and the amount that is revoked and sent to the vesting admin. 
  event PlanRevoked(uint256 indexed id, uint256 amountRedeemed, uint256 revokedAmount);

  /// @notice event emitted when a vesting admin changes itself, assigning a new vesting admin to the plan
  event VestingPlanAdminChanged(uint256 indexed id, address _newVestingAdmin);

  /// @notice event emitted when a plan admin transfers an plan and NFT on behalf of a beneficiary from one wallet address to another
  event PlanTransferredByVestingAdmin(uint256 indexed id, address indexed from, address indexed to);

  /// @notice public function to get the balance of a plan, this function is used by the contracts to calculate how much can be redeemed and revoked, and how to reset the start date
  /// @param planId is the NFT token ID and plan Id
  /// @param timeStamp is the effective current time stamp, can be polled for the future for estimating redeemable tokens
  /// @param redemptionTime is the time of the request that the user is attemptint to redeem tokens, which can be prior to the timeStamp, though not beyond it. 
  function planBalanceOf(
    uint256 planId,
    uint256 timeStamp,
    uint256 redemptionTime
  ) public view returns (uint256 balance, uint256 remainder, uint256 latestUnlock) {
    Plan memory plan = plans[planId];
    (balance, remainder, latestUnlock) = TimelockLibrary.balanceAtTime(
      plan.start,
      plan.cliff,
      plan.amount,
      plan.rate,
      plan.period,
      timeStamp,
      redemptionTime
    );
  }

  /// @dev function to calculate the end date in seconds of a given vesting plan
  /// @param planId is the NFT token ID
  function planEnd(uint256 planId) public view returns (uint256 end) {
    Plan memory plan = plans[planId];
    end = TimelockLibrary.endDate(plan.start, plan.amount, plan.rate, plan.period);
  }
}