// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TimelockLibrary.sol';

/// @notice This contract is the storage contract for the Lockup Plans contracts.
/// it contains the storage of the lockup plan object (Plan struct), as well as the events that the lockup plan contracts emit

contract LockupStorage {
  /// @dev the Plan is the storage in a struct of the tokens that are locked and being unlocked
  /// @param token is the token address being timelocked
  /// @param amount is the current amount of tokens locked in the lockup plan, both unclaimed unlocked and still locked tokens. This parameter is updated each time tokens are redeemed, reset to the new remaining locked and unclaimed amount
  /// @param start is the start date when token unlock begins or began. This parameter gets updated each time tokens are redeemed and claimed, reset to the most recent redeem time
  /// @param cliff is an optional field to add a single cliff date prior to which the tokens cannot be redeemed, this does not change
  /// @param rate is the amount of tokens that unlock in a period. This parameter is constand for each plan. 
  /// @param period is the length of time in between each discrete time when tokens unlock. If this is set to 1, then tokens unlocke every second. Otherwise the period is longer to allow for interval lockup plans. 
  struct Plan {
    address token;
    uint256 amount;
    uint256 start;
    uint256 cliff;
    uint256 rate;
    uint256 period;
  }

  /// @dev a mapping of the planId to the Plan struct. This is also mapped of the NFT token ID to the Plan struct, as the planId is the NFT token Id. 
  mapping(uint256 => Plan) public plans;

  /// @dev this stores the original end date of a plan. This is only used when a token is segmented, which sometimes results in a new end that is longer than the original, 
  /// the original end date is stored for the case of recombining those plans. 
  mapping(uint256 => uint256) public segmentOriginalEnd;

  ///@notice event emitted when a new lockup plan is created, emits the NFT and planId, as well as all of the info from the plan struct
  event PlanCreated(
    uint256 indexed id,
    address indexed recipient,
    address indexed token,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 end,
    uint256 rate,
    uint256 period
  );

  /// @notice event emitted when a beneficiary redeems some or all of the tokens in their plan. 
  /// It emits the id of the plan, as well as the amount redeemed, any remaining unvested or unclaimed tokens and the date that was the effective new start date, the reset date
  event PlanRedeemed(uint256 indexed id, uint256 amountRedeemed, uint256 planRemainder, uint256 resetDate);

  /// @notice this event is emitted when a plan owner segments a plan into a new plan. The event spits out all of the details that have changed for the original plan and the new segmented plan
  event PlanSegmented(
    uint256 indexed id,
    uint256 indexed segmentId,
    uint256 newPlanAmount,
    uint256 newPlanRate,
    uint256 segmentAmount,
    uint256 segmentRate,
    uint256 start,
    uint256 cliff,
    uint256 period,
    uint256 newPlanEnd,
    uint256 segmentEnd
  );

  /// @notice this event is emitted when two plans with the same parameters are combined, it emits the two combined plans ids, the surviving plan id, and the details of the surviving plan
  event PlansCombined(
    uint256 indexed id0,
    uint256 indexed id1,
    uint256 indexed survivingId,
    uint256 amount,
    uint256 rate,
    uint256 start,
    uint256 cliff,
    uint256 period,
    uint256 end
  );

  /// @notice public function to get the balance of a plan, this function is used by the contracts to calculate how much can be redeemed, and how to reset the start date
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
  function planEnd(uint256 planId) external view returns (uint256 end) {
    Plan memory plan = plans[planId];
    end = TimelockLibrary.endDate(plan.start, plan.amount, plan.rate, plan.period);
  }
}
