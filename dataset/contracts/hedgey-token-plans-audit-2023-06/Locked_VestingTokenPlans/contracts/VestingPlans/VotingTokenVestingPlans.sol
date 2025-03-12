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
import '../sharedContracts/VestingStorage.sol';

/// @title VotingTokenVestingPlans - An efficient way to allocate tokens to employees that vest over time
/// @notice This contract allows people to grant tokens to beneficiaries that vest over time with the added functionalities;
/// Each vesting plan is a unique NFT, leveraging the backbone of the ERC721 contract to represent a unique vesting plan 
/// 1. Revokable: plans can be revoked and unvested tokens returned to the company (vesting admin)
/// 2. Soul Bound: plans are by default soul bound and not transferable, however can be transferred by an admin in emergencies
/// 3. Governance optimized for on-chain voting: These are built to allow beneficiaries to vote with their unvested tokens on chain with the standard ERC20Votes contract, as well as on snapshot
/// 4. Beneficiary Claims: Beneficiaries get to choose when to claim their tokens, and can claim partial amounts that are less than the amount they vested for tax optimization

contract VotingTokenVestingPlans is ERC721Enumerable, VestingStorage, ReentrancyGuard, URIAdmin {
  /// @notice uses counters for incrementing token IDs which are the planIds
  using Counters for Counters.Counter;
  Counters.Counter private _planIds;

  /// @dev Voting Vaults are external contracts that hold tokens for a vesting plan allowing an owner to delegate their tokens for on-chain governance
  /// the vesting plan ID is mapped to the votingVault address so that it is one to one and unique to the NFT
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

  /// @notice function to create a vesting plan. 
  /// @dev this function will pull the tokens into this contract for escrow, increment the planIds, mint an NFT to the recipient, and create the storage Plan and map it to the newly minted NFT token ID in storage
  /// @param recipient the address of the recipient and beneficiary of the plan
  /// @param token the address of the ERC20 token
  /// @param amount the amount of tokens to be locked in the plan
  /// @param start the start date of the vesting plan, unix time
  /// @param cliff a cliff date which is a discrete date where tokens are not vested until this date, and then vest in a large single chunk on the cliff date
  /// @param rate the amount of tokens that vest in a single period
  /// @param period the amount of time in between each vesting time stamp, in seconds. A period of 1 means that tokens vest every second in a 'streaming' style. 
  /// @param vestingAdmin is the address of an administrator in charge of revoking the plan, pulling back any unvested tokens to the vestingAdmin address
  /// @param adminTransferOBO is an optional toggle to allow the vestingAdmin to transfer a plan and NFT to another wallet on behalf of (OBO) a beneficiary. To be used only for emergencies.
  function createPlan(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 rate,
    uint256 period,
    address vestingAdmin,
    bool adminTransferOBO
  ) external nonReentrant returns (uint256 newPlanId) {
    require(recipient != address(0), '0_recipient');
    require(token != address(0), '0_token');
    (uint256 end, bool valid) = TimelockLibrary.validateEnd(start, cliff, amount, rate, period);
    require(valid);
    _planIds.increment();
    newPlanId = _planIds.current();
    TransferHelper.transferTokens(token, msg.sender, address(this), amount);
    plans[newPlanId] = Plan(token, amount, start, cliff, rate, period, vestingAdmin, adminTransferOBO);
    _safeMint(recipient, newPlanId);
    emit PlanCreated(
      newPlanId,
      recipient,
      token,
      amount,
      start,
      cliff,
      end,
      rate,
      period,
      vestingAdmin,
      adminTransferOBO
    );
  }

  /// @notice function for a beneficiary to redeem vested tokens from a group of plans
  /// @dev this will call an internal function for processing the actual redemption of tokens, which will withdraw vested tokens and deliver them to the beneficiary
  /// @dev this function will redeem all claimable and vested tokens up to the current block.timestamp
  /// @param planIds is the array of the NFT planIds that are to be redeemed. If any have no redeemable balance they will be skipped. 
  function redeemPlans(uint256[] memory planIds) external nonReentrant {
    _redeemPlans(planIds, block.timestamp);
  }

  /// @notice function for a beneficiary to redeem vested tokens from a group of plans
  /// @dev this will call an internal function for processing the actual redemption of tokens, which will withdraw vested tokens and deliver them to the beneficiary
  /// @dev this function will redeem only a partial amount of tokens based on a redemption timestamp that is in the past. This allows holders to redeem less than their fully vested amount for various reasons
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

  /// @notice the function for a vestingAdmin to revoke vesting plans. 
  /// @dev this will call an internal function to revoke plans, whereby unvested tokens will be returned to the vestingAdmin, and any tokens that are vested will be delivered to the beneficiary(s)
  /// @param planIds is the array of the plan ids to be redeemed. the caller must be the vesting admin for all of the plans.
  function revokePlans(uint256[] memory planIds) external nonReentrant {
    for (uint256 i; i < planIds.length; i++) {
      _revokePlan(msg.sender, planIds[i]);
    }
  }

  /// @notice the function for a vestingAdmin to assing a new vestingAdmin wallet for a specific plan. Used in emergencies where DAOs are changing multi-sigs or other events
  /// @dev the new vesting admin address cannot be the beneficiary of the plan
  /// @param planId is the NFT token id of the plan
  /// @param newVestingAdmin is the address which the vesting admin of the plan will be assigned
  function changeVestingPlanAdmin(uint256 planId, address newVestingAdmin) external {
    Plan storage plan = plans[planId];
    require(msg.sender == plan.vestingAdmin, '!vestingAdmin');
    require(ownerOf(planId) != newVestingAdmin, '!planOwner');
    plan.vestingAdmin = newVestingAdmin;
    emit VestingPlanAdminChanged(planId, newVestingAdmin);
  }

  /****EXTERNAL VOTING & DELGATION FUNCTIONS*********************************************************************************************************************************************/
  /// @notice functions for the owners of vesting plans to setup on chain voting vaults, and then delegate those tokens. 
  /// these are explicity for tokens that are of the ERC20Votes format, which have a delegate and delegates function. 
  /// tokens that do not have the standard delegate and delegates functionality for on-chain voting will revert when delegating or creating onchain voting vaults. 

  /// @notice function to setup a voting vault, this calls an internal voting function to set it up
  /// @param planId is the id of the vesting plan and NFT
  function setupVoting(uint256 planId) external nonReentrant returns (address votingVault) {
    votingVault = _setupVoting(msg.sender, planId);
  }

  /// @notice function for an owner of a vesting plan to delegate a single vesting plan to  single delegate
  /// @dev this will call an internal delegate function for processing
  /// if there is no voting vault setup, this function will automatically create a voting vault and then delegate the tokens to the delegatee
  /// @param planId is the id of the vesting plan and NFT
  function delegate(uint256 planId, address delegatee) external nonReentrant {
    _delegate(msg.sender, planId, delegatee);
  }

  /// @notice this function allows an owner of multiple vesting plans to delegate multiple of them in a single transaction, each planId corresponding to a delegatee address
  /// @param planIds is the ids of the vesting plan and NFT
  /// @param delegatees is the array of addresses where each vesting plan will delegate the tokens to
  function delegatePlans(uint256[] memory planIds, address[] memory delegatees) external nonReentrant {
    require(planIds.length == delegatees.length, 'array error');
    for (uint256 i; i < planIds.length; i++) {
      _delegate(msg.sender, planIds[i], delegatees[i]);
    }
  }

  /// @notice this function lets an owner delegate all of their vesting plans for a single token to a single delegatee
  /// @dev this function will iterate through all of the owned vesting plans of the msg.sender, and if the token address matches the vesting plan token address, it will delegate that plan
  /// @param token is the ERC20Votes token address that the owner is vesting
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

  /// @notice internal function that process the redemption for a single vesting plan
  /// @dev this takes the inputs from the _redeemPlans and processes the redemption delivering the available balance of redeemable tokens to the beneficiary
  /// If the tokens are held in an external voting vault, then tokens are withdrawn from the voting vault, rather than transferred from this contract
  /// if the plan is fully redeemed, as defined that the balance == amount, then the plan is deleted and NFT burned
  /// if the plan is not fully redeemed, then the storage of start and amount are updated to reflect the remaining amount and most recent time redeemed for the new start date
  /// @param holder is the address of the holder of the plan and NFT
  /// @param planId is the id of the vesting plan and NFT
  /// @param balance is the available redeemable balance
  /// @param remainder is the amount of tokens that are still unvested in the plan, and will be the new amount in the plan storage
  /// @param latestUnlock is the most recent timestamp for when redemption occured. Because periods may be longer than 1 second, the latestUnlock time may be the current block time, or the timestamp of the most recent period timestamp
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

  /// @notice the internal function to revoke a vesting plan
  /// @dev this is called by the external revokePlans function, which inputs the msg.sender as the vestingAdmin and the planId from the inputs
  /// this function checks that the vestingAdmin is the vestingAdmin, and that there is actually a revokable balance. 
  /// The function then withdraws the unvested tokens that are revoked, delivering them to the vestingAdmin
  /// the function then transfers the vested balances to the plan beneficiary. 
  /// if the plan has an external voting vault setup, then tokens will be withdrawn from the voting vault rather than this contract address
  /// finally the function deletes the plan held in storage and burns the NFT. 
  /// @param vestingAdmin is the vestingAdmin address 
  /// @param planId is the id of the plan and NFT
  function _revokePlan(address vestingAdmin, uint256 planId) internal {
    Plan memory plan = plans[planId];
    require(vestingAdmin == plan.vestingAdmin, '!vestingAdmin');
    (uint256 balance, uint256 remainder, ) = planBalanceOf(planId, block.timestamp, block.timestamp);
    require(remainder > 0, '!Remainder');
    address holder = ownerOf(planId);
    delete plans[planId];
    _burn(planId);
    address vault = votingVaults[planId];
    if (vault == address(0)) {
      TransferHelper.withdrawTokens(plan.token, vestingAdmin, remainder);
      TransferHelper.withdrawTokens(plan.token, holder, balance);
    } else {
      delete votingVaults[planId];
      VotingVault(vault).withdrawTokens(vestingAdmin, remainder);
      VotingVault(vault).withdrawTokens(holder, balance);
    }
    emit PlanRevoked(planId, balance, remainder);
  }

  /****INTERNAL VOTING FUNCTIONS*********************************************************************************************************************************************/

  /// @notice the internal function to setup a voting vault. 
  /// @dev this will check that no voting vault exists already and then deploy a new voting vault contract
  // during the constructor setup of the voting vault, it will auto delegate the voting vault address to whatever the existing delegate of the vesting plan holder has delegated to
  // if it has not delegated yet, it will self-delegate the tokens
  /// then transfer the tokens remaining in the vesting plan to the voting vault physically
  /// @param holder is the address of the holer of th vesting plan and NFT
  /// @param planId is the id of the vesting plan and NFT
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
  /// @param holder is the address of the holer of th vesting plan and NFT
  /// @param planId is the id of the vesting plan and NFT
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
  /// @param holder is the address of the beneficiary who owns the vesting plan(s)
  /// @param token is the ERC20 address of the token that is stored across the vesting plans
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

  /****NFT FRANSFER SPECIAL OVERRIDE FUNCTIONS*********************************************************************************************************************************************/

  /// @notice special function to transfer an NFT that overrides the normal ERC721 transferFrom function.
  /// this function lets a vestingAdmin of a plan transfer the NFT on behalf of a the holder of an NFT. 
  /// the vesting plan must have the adminTransferOBO toggle turned on to true for this function to be called. 
  /// this functin cannot be called by the owner / beneficiary of the NFT and vesting plan. 
  /// the to address cannot be the vestingAdmin address
  /// @param from is the address the NFT and plan is transferred from
  /// @param to is the address where the NFT and plan is being transferred to
  /// @param tokenId is the NFT tokenID, the same as the planId to be transferred
  function transferFrom(address from, address to, uint256 tokenId) public override(IERC721, ERC721) {
    require(plans[tokenId].adminTransferOBO, '!transferrable');
    require(to != plans[tokenId].vestingAdmin, '!transfer to admin');
    require(msg.sender == plans[tokenId].vestingAdmin, '!vestingAdmin');
    _transfer(from, to, tokenId);
    emit PlanTransferredByVestingAdmin(tokenId, from, to);
  }

  /// @notice vesting plans are not transferable, with the exception of the above method. 
  function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal override {
    revert('!transferrable');
  }
}
