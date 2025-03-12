// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '../libraries/TransferHelper.sol';
import '../libraries/TimelockLibrary.sol';
import '../sharedContracts/VotingVault.sol';
import '../sharedContracts/URIAdmin.sol';
import '../sharedContracts/LockupStorage.sol';

/// @title TokenLockupPlans - An efficient way to allocate tokens to beneficiaries that unlock over time
/// @notice This contract allows people to grant tokens to beneficiaries that unlock over time with the added functionalities;
/// Owners of unlock plans can manage all of their token unlocks across all of their positions in a single contract. 
/// Each lockup plan is a unique NFT, leveraging the backbone of the ERC721 contract to represent a unique lockup plan 
/// 1. Not-Revokable: plans cannot be revoked, once granted the entire amount will be claimable by the beneficiary over time. 
/// 2. Transferable: Lockup plans can be transferred by the owner - opening up defi opportunities like NFT sales, borrowing and lending, and many others. 
/// 3. Governance optimized for on-chain voting: These are built to allow beneficiaries to vote with their unvested tokens on chain with the standard ERC20Votes contract, as well as on snapshot
/// 4. Beneficiary Claims: Beneficiaries get to choose when to claim their tokens, and can claim partial amounts that are less than the amount they have unlocked for tax optimization
/// 5. Segmenting plans: Beneficiaries can segment a single lockup into  smaller chunks for subdelegation of tokens, or to use in defi with smaller chunks
/// 6. Combingin Plans: Beneficiaries can combine plans that have the same details in one larger chunk for easier bulk management
contract VotingTokenLockupPlans is ERC721Enumerable, LockupStorage, ReentrancyGuard, URIAdmin {
    /// @notice uses counters for incrementing token IDs which are the planIds
  using Counters for Counters.Counter;
  Counters.Counter private _planIds;

  /// @dev Voting Vaults are external contracts that hold tokens for a lockup plan allowing an owner to delegate their tokens for on-chain governance
  /// the lockup plan ID is mapped to the votingVault address so that it is one to one and unique to the NFT
  mapping(uint256 => address) public votingVaults;

  /// @notice event emitted when a new voting vault is generated and setup
  event VotingVaultCreated(uint256 indexed id, address vaultAddress);

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    uriAdmin = msg.sender;
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  /****CORE EXTERNAL FUNCTIONS*********************************************************************************************************************************************/

  /// @notice function to create a lockup plan. 
  /// @dev this function will pull the tokens into this contract for escrow, increment the planIds, mint an NFT to the recipient, and create the storage Plan and map it to the newly minted NFT token ID in storage
  /// @param recipient the address of the recipient and beneficiary of the plan
  /// @param token the address of the ERC20 token
  /// @param amount the amount of tokens to be locked in the plan
  /// @param start the start date of the lockup plan, unix time
  /// @param cliff a cliff date which is a discrete date where tokens are not unlocked until this date, and then vest in a large single chunk on the cliff date
  /// @param rate the amount of tokens that vest in a single period
  /// @param period the amount of time in between each unlock time stamp, in seconds. A period of 1 means that tokens vest every second in a 'streaming' style. 
  function createPlan(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 rate,
    uint256 period
  ) external nonReentrant returns (uint256 newPlanId) {
    require(recipient != address(0), '0_recipient');
    require(token != address(0), '0_token');
    (uint256 end, bool valid) = TimelockLibrary.validateEnd(start, cliff, amount, rate, period);
    require(valid);
    _planIds.increment();
    newPlanId = _planIds.current();
    TransferHelper.transferTokens(token, msg.sender, address(this), amount);
    plans[newPlanId] = Plan(token, amount, start, cliff, rate, period);
    _safeMint(recipient, newPlanId);
    emit PlanCreated(newPlanId, recipient, token, amount, start, cliff, end, rate, period);
  }

  /// @notice function for a beneficiary to redeem unlocked tokens from a group of plans
  /// @dev this will call an internal function for processing the actual redemption of tokens, which will withdraw unlocked tokens and deliver them to the beneficiary
  /// @dev this function will redeem all claimable and unlocked tokens up to the current block.timestamp
  /// @param planIds is the array of the NFT planIds that are to be redeemed. If any have no redeemable balance they will be skipped. 
  function redeemPlans(uint256[] memory planIds) external nonReentrant {
    _redeemPlans(planIds, block.timestamp);
  }

  /// @notice function for a beneficiary to redeem unlocked tokens from a group of plans
  /// @dev this will call an internal function for processing the actual redemption of tokens, which will withdraw unlocked tokens and deliver them to the beneficiary
  /// @dev this function will redeem only a partial amount of tokens based on a redemption timestamp that is in the past. This allows holders to redeem less than their fully unlocked amount for various reasons
  /// @param planIds is the array of the NFT planIds that are to be redeemed. If any have no redeemable balance they will be skipped.
  /// @param redemptionTime is the timestamp which will calculate the amount of tokens redeemable and redeem them based on that timestamp
  function partialRedeemPlans(uint256[] memory planIds, uint256 redemptionTime) external nonReentrant {
    require(redemptionTime < block.timestamp, '!future');
    _redeemPlans(planIds, redemptionTime);
  }

  /// @notice this function will redeem all plans owned by a single wallet - useful for custodians or other intermeidaries that do not have the ability to lookup individual planIds
  /// @dev this will iterate through all of the plans owned by the wallet based on the ERC721Enumerable backbone, and redeem each one with a redemption time of the current block.timestamp
  function redeemAllPlans() external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    uint256[] memory planIds = new uint256[](balance);
    for (uint256 i; i < balance; i++) {
      uint256 planId = tokenOfOwnerByIndex(msg.sender, i);
      planIds[i] = planId;
    }
    _redeemPlans(planIds, block.timestamp);
  }

  /// @notice function for an owner of a lockup plan to segment a single plan into multiple chunks; segments. 
  /// @dev the single plan can be divided up into many segments in this transaction, but care must be taken to ensure that the array is processed in a proper order
  /// if the tokens are send in the wrong order the function will revert becuase the amount of the segment could be larger than the original plan. 
  /// this function iterates through the segment amounts and breaks up the same original plan into smaller sizes
  /// each time a segment happens it is always with the single planId, which will generate a new NFT for each new segment, and the original plan is updated in storage
  /// the original plan amount newPlanAmount + segmentAmount && original plan Rate = newPlanRate + segmentRate
  /// IF The plan that is being segmented has a voting vault setup, it will generate a new voting vault for the segmented tokens, however it will not delegate those
  /// @dev Segmenting plans where the segment amount is not divisible by the rate will result in a new End date that is 1 period farther than the original plan
  /// @param planId is the plan that is going to be segmented
  /// @param segmentAmounts is the array of amounts of each individual segment, which must each be smaller than the plan when it is being segmented.
  function segmentPlan(
    uint256 planId,
    uint256[] memory segmentAmounts
  ) external nonReentrant returns (uint256[] memory newPlanIds) {
    newPlanIds = new uint256[](segmentAmounts.length);
    for (uint256 i; i < segmentAmounts.length; i++) {
      uint256 newPlanId = _segmentPlan(msg.sender, planId, segmentAmounts[i]);
      newPlanIds[i] = newPlanId;
    }
  }

  /// @notice this function combines the functionality of segmenting plans and then immediately delegating the new semgent plans to a delegate address
  /// @dev this function does NOT delegate the original planId at all, it will only delegate the newly create segments
  /// if the plan has a Voting Vault, it will create a new voting vault for each segment, and then delegate the tokens in the voting vault to the delegatee address
  /// @param planId is the plan that will be segmented (and not delegated)
  /// @param segmentAmounts is the array of each segment amount
  /// @param delegatees is the array of delegatees that each new segment will be delegated to 
  function segmentAndDelegatePlans(
    uint256 planId,
    uint256[] memory segmentAmounts,
    address[] memory delegatees
  ) external nonReentrant returns (uint256[] memory newPlanIds) {
    require(segmentAmounts.length == delegatees.length, '!length');
    newPlanIds = new uint256[](segmentAmounts.length);
    for (uint256 i; i < segmentAmounts.length; i++) {
      uint256 newPlanId = _segmentPlan(msg.sender, planId, segmentAmounts[i]);
      _delegate(msg.sender, newPlanId, delegatees[i]);
      newPlanIds[i] = newPlanId;
    }
  }

  /// @notice this function allows a beneficiary of two plans that share the same details to combine them into a single surviving plan
  /// @dev the plans must have the same details except the amount and rate, but must share the same end date to be combined
  /// if one of the plans has a voting vault, that plan will be the surviving plan and all tokens will be transferred to the surviving plan voting vault
  /// @param planId0 is the planId of a first plan to be combined
  /// @param planId1 is the planId of a second plan to be combined
  function combinePlans(uint256 planId0, uint256 planId1) external nonReentrant returns (uint256 survivingPlanId) {
    survivingPlanId = _combinePlans(msg.sender, planId0, planId1);
  }

  /****EXTERNAL VOTING FUNCTIONS*********************************************************************************************************************************************/
  /// @notice functions for the owners of lockup plans to setup on chain voting vaults, and then delegate those tokens. 
  /// these are explicity for tokens that are of the ERC20Votes format, which have a delegate and delegates function. 
  /// tokens that do not have the standard delegate and delegates functionality for on-chain voting will revert when delegating or creating onchain voting vaults. 

  /// @notice function to setup a voting vault, this calls an internal voting function to set it up
  // this will physically transfer tokens to the new voting vault contract once deployed
  /// @param planId is the id of the lockup plan and NFT
  function setupVoting(uint256 planId) external nonReentrant returns (address votingVault) {
    votingVault = _setupVoting(msg.sender, planId);
  }

  /// @notice function for an owner of a lockup plan to delegate a single lockup plan to  single delegate
  /// @dev this will call an internal delegate function for processing
  /// if there is no voting vault setup, this function will automatically create a voting vault and then delegate the tokens to the delegatee
  /// @param planId is the id of the lockup plan and NFT
  function delegate(uint256 planId, address delegatee) external nonReentrant {
    _delegate(msg.sender, planId, delegatee);
  }

 /// @notice this function allows an owner of multiple lockup plans to delegate multiple of them in a single transaction, each planId corresponding to a delegatee address
  /// @param planIds is the ids of the lockup plan and NFT
  /// @param delegatees is the array of addresses where each lockup plan will delegate the tokens to
  function delegatePlans(uint256[] memory planIds, address[] memory delegatees) external nonReentrant {
    require(planIds.length == delegatees.length, 'array error');
    for (uint256 i; i < planIds.length; i++) {
      _delegate(msg.sender, planIds[i], delegatees[i]);
    }
  }

  /// @notice this function lets an owner delegate all of their lockup plans for a single token to a single delegatee
  /// @dev this function will iterate through all of the owned lockup plans of the msg.sender, and if the token address matches the lockup plan token address, it will delegate that plan
  /// @param token is the ERC20Votes token address of the tokens in the lockup plans
  /// @param delegatee is the address of the delegate that the beneficiary is delegating their tokens to
  function delegateAll(address token, address delegatee) external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    for (uint256 i; i < balance; i++) {
      uint256 planId = tokenOfOwnerByIndex(msg.sender, i);
      if (plans[planId].token == token) _delegate(msg.sender, planId, delegatee);
    }
  }

  /****CORE INTERNAL FUNCTIONS*********************************************************************************************************************************************/

  /// @notice function that will intake an array of planIds and a redemption time, and then check the balances that are available to be redeemed
  /// @dev if the nft has an available balance, it is then passed on to the _redeemPlan function for further processing
  /// if there is no balance to be redeemed, the plan is skipped from being processed
  /// @param planIds is the array of plans to be redeemed
  /// @param redemptionTime is the requested redemption time, either the current block.timestamp or a timestamp from the past, but must be greater than the start date
  function _redeemPlans(uint256[] memory planIds, uint256 redemptionTime) internal {
    for (uint256 i; i < planIds.length; i++) {
      (uint256 balance, uint256 remainder, uint256 latestUnlock) = planBalanceOf(
        planIds[i],
        block.timestamp,
        redemptionTime
      );
      if (balance > 0) _redeemPlan(msg.sender, planIds[i], balance, remainder, latestUnlock);
    }
  }

  /// @notice internal function that process the redemption for a single lockup plan
  /// @dev this takes the inputs from the _redeemPlans and processes the redemption delivering the available balance of redeemable tokens to the beneficiary
  /// if the plan has a voting vault then tokens will be redeemed and transferred from the voting vault to the beneficiary. 
  /// if the plan is fully redeemed, as defined that the balance == amount, then the plan is deleted and NFT burned
  // if the plan is not fully redeemed, then the storage of start and amount are updated to reflect the remaining amount and most recent time redeemed for the new start date
  /// @param holder is the address of the holder of the plan and NFT
  /// @param planId is the id of the lockup plan and NFT
  /// @param balance is the available redeemable balance
  /// @param remainder is the amount of tokens that are still lcoked in the plan, and will be the new amount in the plan storage
  /// @param latestUnlock is the most recent timestamp for when redemption occured. Because periods may be longer than 1 second, 
  /// the latestUnlock time may be the current block time, or the timestamp of the most recent period timestamp
  function _redeemPlan(
    address holder,
    uint256 planId,
    uint256 balance,
    uint256 remainder,
    uint256 latestUnlock
  ) internal {
    require(ownerOf(planId) == holder, '!owner');
    address token = plans[planId].token;
    address vault = votingVaults[planId];
    if (remainder == 0) {
      delete plans[planId];
      delete votingVaults[planId];
      _burn(planId);
    } else {
      plans[planId].amount = remainder;
      plans[planId].start = latestUnlock;
    }
    if (vault == address(0)) {
      TransferHelper.withdrawTokens(token, holder, balance);
    } else {
      VotingVault(vault).withdrawTokens(holder, balance);
    }
    emit PlanRedeemed(planId, balance, remainder, latestUnlock);
  }

  /// @notice the internal function for segmenting a single plan into two 
  /// @dev the function takes a plan, performs some checks that the segment amount cannot be 0 and must be strictly less than the original plan amount
  /// then it will subtract the segmentamount from the original plan amount to get the new plan amount
  /// then it will get a new pro-rata rate for the newplan based on the new plan amount divided by the original plan amount
  /// while this pro-rata new rate is not perfect because of unitization (ie no decimal suppport), the segment rate is calculated by subtracting the new plan rate from the original plan rate
  /// because the newplan amount and segment amount == original plan amount, and the new plan rate + segment rate == original plan rate, the beneficiary will still unlock the same number of tokens at approximatley the same rate
  /// however because of uneven division, the end dates of each of the new rates may be different than the original rate. We check to make sure that the new end is farther than the original end
  /// so that tokens do not unlock early, and then it is a valid segment. 
  /// finally a new NFT is minted with the Segment plan details
  /// and the storage of the original plan amount and rate is updated with the newplan amount and rate. 
  /// at the end this checks if there is a voting vault setup for the original plan. If there is a voting vault setup, it will transfer tokens back from the original plan vault, 
  /// then setup a new voting vault for the segment plan, thereby transferring the segment tokens to the new segment voting vault
  /// @param holder is the owner of the lockup plan and NFT
  /// @param planId is the id of the lockup plan
  /// @param segmentAmount is the amount of tokens to be segmented off from the original plan and created into a new segment plan
  function _segmentPlan(address holder, uint256 planId, uint256 segmentAmount) internal returns (uint256 newPlanId) {
    require(ownerOf(planId) == holder, '!owner');
    Plan memory plan = plans[planId];
    require(segmentAmount < plan.amount, 'amount error');
    require(segmentAmount > 0, '0_segment');
    uint256 end = TimelockLibrary.endDate(plan.start, plan.amount, plan.rate, plan.period);
    _planIds.increment();
    newPlanId = _planIds.current();
    _safeMint(holder, newPlanId);
    uint256 planAmount = plan.amount - segmentAmount;
    plans[planId].amount = planAmount;
    uint256 planRate = (plan.rate * ((planAmount * (10 ** 18)) / plan.amount)) / (10 ** 18);
    plans[planId].rate = planRate;
    uint256 segmentRate = plan.rate - planRate;
    (uint256 planEnd, bool validPlan) = TimelockLibrary.validateEnd(
      plan.start,
      plan.cliff,
      planAmount,
      planRate,
      plan.period
    );
    (uint256 segmentEnd, bool validSegment) = TimelockLibrary.validateEnd(
      plan.start,
      plan.cliff,
      segmentAmount,
      segmentRate,
      plan.period
    );
    require(validPlan && validSegment, 'invalid new plans');
    uint256 endCheck = segmentOriginalEnd[planId] == 0 ? end : segmentOriginalEnd[planId];
    require(planEnd >= endCheck, 'plan end error');
    require(segmentEnd >= endCheck, 'segmentEnd error');
    plans[newPlanId] = Plan(plan.token, segmentAmount, plan.start, plan.cliff, segmentRate, plan.period);
    if (segmentOriginalEnd[planId] == 0) {
      segmentOriginalEnd[planId] = end;
      segmentOriginalEnd[newPlanId] = end;
    } else {
      segmentOriginalEnd[newPlanId] = segmentOriginalEnd[planId];
    }
    if (votingVaults[planId] != address(0)) {
      VotingVault(votingVaults[planId]).withdrawTokens(address(this), segmentAmount);
      _setupVoting(holder, newPlanId);
    }
    emit PlanSegmented(
      planId,
      newPlanId,
      planAmount,
      planRate,
      segmentAmount,
      segmentRate,
      plan.start,
      plan.cliff,
      plan.period,
      planEnd,
      segmentEnd
    );
  }

  /// @notice this funtion allows the holder of two plans that have the same parameters to combine them into a single surviving plan
  /// @dev all of the details of the plans must be the same except the amounts and rates may be different
  /// this function will check that the owners are the same, the ERC20 tokens are the same, the start, cliff and periods are the same. 
  /// then it performs some checks on the end dates to ensure that either the end dates are the same, or if the user is combining previously segmented plans,
  /// that the original end dates of those segments are the same. 
  /// if everything checks out, and the new end date of the combined plan will result in an end date equal to or later than the two plans, then they can be combined
  /// combining plans will delete the plan1 and burn the NFT related to it
  /// and then update the storage of the plan0 with the combined amount and combined rate
  /// if One of the plans has a voting vault, then that plan will be the survivor and then tokens will be transferred and consolidated into that plan
  /// if both have a voting vault, then plan0 will be the survivor and tokens consolidated to plan0 voting vault
  /// if neither have a voting vault then nothing is done for voting vaults. 
  /// @param holder is the owner of both lockup plans
  /// @param planId0 is the planId of the first plan in the combination
  /// @param planId1 is the planId of a second plan to be combined
  function _combinePlans(address holder, uint256 planId0, uint256 planId1) internal returns (uint256 survivingPlan) {
    require(ownerOf(planId0) == holder, '!owner');
    require(ownerOf(planId1) == holder, '!owner');
    Plan memory plan0 = plans[planId0];
    Plan memory plan1 = plans[planId1];
    require(plan0.token == plan1.token, 'token error');
    require(plan0.start == plan1.start, 'start error');
    require(plan0.cliff == plan1.cliff, 'cliff error');
    require(plan0.period == plan1.period, 'period error');
    uint256 plan0End = TimelockLibrary.endDate(plan0.start, plan0.amount, plan0.rate, plan0.period);
    uint256 plan1End = TimelockLibrary.endDate(plan1.start, plan1.amount, plan1.rate, plan1.period);
    require(plan0End == plan1End || (segmentOriginalEnd[planId0] == segmentOriginalEnd[planId1] && segmentOriginalEnd[planId0] != 0), 'end error');
    address vault0 = votingVaults[planId0];
    address vault1 = votingVaults[planId1];
    survivingPlan = planId0;
    if (vault0 != address(0)) {
      plans[planId0].amount += plans[planId1].amount;
      plans[planId0].rate += plans[planId1].rate;
      uint256 end = TimelockLibrary.endDate(plan0.start, plans[planId0].amount, plans[planId0].rate, plan0.period);
      if (end < plan0End) {
        require(end == segmentOriginalEnd[planId0] || end == segmentOriginalEnd[planId1], 'original end error');
      }
      if (vault1 != address(0)) {
        VotingVault(vault1).withdrawTokens(vault0, plan1.amount);
      } else {
        TransferHelper.withdrawTokens(plan0.token, vault0, plan1.amount);
      }
      delete plans[planId1];
      _burn(planId1);
      emit PlansCombined(
        planId0,
        planId1,
        survivingPlan,
        plans[planId0].amount,
        plans[planId0].rate,
        plan0.start,
        plan0.cliff,
        plan0.period,
        end
      );
    } else if (vault1 != address(0)) {
      plans[planId1].amount += plans[planId0].amount;
      plans[planId1].rate += plans[planId0].rate;
      uint256 end = TimelockLibrary.endDate(plan1.start, plans[planId1].amount, plans[planId1].rate, plan1.period);
      if (end < plan1End) {
        require(end == segmentOriginalEnd[planId0] || end == segmentOriginalEnd[planId1], 'original end error');
      }
      TransferHelper.withdrawTokens(plan0.token, vault1, plan0.amount);
      survivingPlan = planId1;
      delete plans[planId0];
      _burn(planId0);
      emit PlansCombined(
        planId0,
        planId1,
        survivingPlan,
        plans[planId1].amount,
        plans[planId1].rate,
        plan1.start,
        plan1.cliff,
        plan1.period,
        end
      );
    } else {
      plans[planId0].amount += plans[planId1].amount;
      plans[planId0].rate += plans[planId1].rate;
      uint256 end = TimelockLibrary.endDate(plan0.start, plans[planId0].amount, plans[planId0].rate, plan0.period);
      if (end < plan0End) {
        require(end == segmentOriginalEnd[planId0] || end == segmentOriginalEnd[planId1], 'original end error');
      }
      delete plans[planId1];
      _burn(planId1);
      emit PlansCombined(
        planId0,
        planId1,
        survivingPlan,
        plans[planId0].amount,
        plans[planId0].rate,
        plan0.start,
        plan0.cliff,
        plan0.period,
        end
      );
    }
  }

  

  /****INTERNAL VOTING & DELEGATION FUNCTIONS*********************************************************************************************************************************************/

  /// @notice the internal function to setup a voting vault. 
  /// @dev this will check that no voting vault exists already and then deploy a new voting vault contract
  // during the constructor setup of the voting vault, it will auto delegate the voting vault address to whatever the existing delegate of the  plan holder has delegated to
  // if it has not delegated yet, it will self-delegate the tokens
  /// then transfer the tokens remaining in the lockup plan to the voting vault physically
  /// @param holder is the address of the holer of th lockup plan and NFT
  /// @param planId is the id of the lockup plan and NFT
  function _setupVoting(address holder, uint256 planId) internal returns (address) {
    require(ownerOf(planId) == holder, '!owner');
    require(votingVaults[planId] == address(0), 'exists');
    Plan memory plan = plans[planId];
    VotingVault vault = new VotingVault(plan.token, holder);
    votingVaults[planId] = address(vault);
    TransferHelper.withdrawTokens(plan.token, address(vault), plan.amount);
    emit VotingVaultCreated(planId, address(vault));
    return address(vault);
  }

  /// @notice this internal function will physically delegate tokens held in a voting vault to a delegatee
  /// @dev if a voting vautl has not been setup yet, then the function will call the internal _setupVoting function and setup a new voting vault
  /// and then it will delegate the tokens held in the vault to the delegatee
  /// @param holder is the address of the holer of th lockup plan and NFT
  /// @param planId is the id of the lockup plan and NFT
  /// @param delegatee is the address of the delegatee where the tokens in the voting vault will be delegated to
  function _delegate(address holder, uint256 planId, address delegatee) internal {
    require(ownerOf(planId) == holder, '!owner');
    address vault = votingVaults[planId];
    if (votingVaults[planId] == address(0)) {
      vault = _setupVoting(holder, planId);
    }
    VotingVault(vault).delegateTokens(delegatee);
  }

  /****VIEW VOTING FUNCTIONS*********************************************************************************************************************************************/

  /// @notice this function will pull all of the unclaimed tokens for a specific holder across all of their plans, based on a single ERC20 token
  /// very useful for snapshot voting, and other view functionalities. This aggregates all balances, including any in voting vaults. 
  /// @param holder is the address of the beneficiary who owns the lockup plan(s)
  /// @param token is the ERC20 address of the token that is stored across the lockup plans
  function lockedBalances(address holder, address token) external view returns (uint256 lockedBalance) {
    uint256 holdersBalance = balanceOf(holder);
    for (uint256 i; i < holdersBalance; i++) {
      uint256 planId = tokenOfOwnerByIndex(holder, i);
      Plan memory plan = plans[planId];
      if (token == plan.token) {
        lockedBalance += plan.amount;
      }
    }
  }
}
