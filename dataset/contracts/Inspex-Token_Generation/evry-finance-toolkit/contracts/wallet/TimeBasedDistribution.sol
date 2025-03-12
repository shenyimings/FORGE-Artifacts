//contracts/wallet/TimeBasedDistribution.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract TimeBasedDistribution is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event AddMember(address indexed memberAddress, uint256 allocation);
  event LockReward(address indexed memberAddress, uint256 amount);
  event ReleaseReward(address indexed memberAddress, uint256 amount);
  event ReleaseJackpotReward(address indexed memberAddress, uint256 amount);
  event DistributionInfo(uint256 lockPeriods, uint256 releasePeriods, uint256 nextUpdateBlock);
  event UpdateMemberAllocation(address indexed memberAddress, uint256 allocation);
  event RemoveMemberAllocation(address indexed memberAddress, uint256 lastLockedAmount);

  struct Member {
    uint256 allocation;
    uint256 lockedAmount;
    uint256 releaseAmountPerPeriod;
    uint256 effectiveJackpotBlock;
  }

  uint256 private constant MAX_INT = (2**256) - 1;
  uint256 public lastUpdateBlock;
  uint256 public nextUpdateBlock;
  uint256 public startReleaseBlock;

  IERC20 public token;
  uint256 public paymentPeriodInBlock; // monthly(30*28800), daily(28800)
  uint256 public numberOfLockPeriod; // number of period multiply to paymentPeriodInBlock (ex 12 means lock 12 paymentPeriodInBlock)
  uint256 public minAllocation; // use for validation when assign new member
  uint256 public maxAllocation; // use for validation when assign new member
  uint256 public distributionCap; // total amount to distribute
  uint256 public distributionTimes; // how many time total amount will be distributed (ex 60 means, release 60 times)
  uint256 public totalDistributed; // total distributed amount (paid to target)
  uint256 public distributePerPeriod; // Amount of token to be distributed per payment period
  uint256 public jackpotReward; // Amount of token from left member
  uint256 public jackpotDistributionTimes; // release period + 1, ex 24 + 1
  uint256 public jackpotReleaseBlock;

  mapping(address => Member) public memberInfo;
  address[] private members;
  uint256 public totalAllocation;
  uint256 public lastReleaseBlock;

  constructor(
    IERC20 _token,
    uint256 _paymentPeriodInBlock,
    uint256 _numberOfLockPeriod,
    uint256 _lastUpdateBlock,
    uint256 _minAllocation,
    uint256 _maxAllocation,
    uint256 _distributionCap,
    uint256 _distributionTimes,
    uint256 _jackpotDistributionTimes
  ) {
    token = _token;
    paymentPeriodInBlock = _paymentPeriodInBlock;
    lastUpdateBlock = _lastUpdateBlock;
    minAllocation = _minAllocation;
    maxAllocation = _maxAllocation;
    numberOfLockPeriod = _numberOfLockPeriod;
    distributionCap = _distributionCap;
    distributionTimes = _distributionTimes;
    jackpotDistributionTimes = _jackpotDistributionTimes;

    totalDistributed = 0;
    nextUpdateBlock = lastUpdateBlock.add(paymentPeriodInBlock);
    startReleaseBlock = nextUpdateBlock.add(paymentPeriodInBlock.mul(numberOfLockPeriod));
    distributePerPeriod = distributionCap.div(distributionTimes);
    jackpotReleaseBlock = lastUpdateBlock.add(jackpotDistributionTimes.mul(paymentPeriodInBlock));

    // prevent distribute reward after last distribution block
    lastReleaseBlock = distributionTimes.mul(paymentPeriodInBlock).add(nextUpdateBlock);
  }

  function transferExceedAmount(address _to) external onlyOwner {
    require(_to != address(0), "TimeBasedDistribution: cannot transfer exceed amount to zero address");
    uint256 totalBalance = token.balanceOf(address(this)).add(totalDistributed);
    require(totalBalance > distributionCap, "TimeBasedDistribution: balance is not exceed");
    token.safeTransfer(_to, totalBalance.sub(distributionCap));
  }

  function addMember(address _memberAddress, uint256 _allocation) external onlyOwner {
    require(_memberAddress != address(0), "TimeBasedDistribution: cannot add zero address to member");
    require(memberInfo[_memberAddress].allocation == 0, "TimeBasedDistribution: member already existed");
    require(
      _allocation >= minAllocation && _allocation <= maxAllocation,
      "TimeBasedDistribution: allocation is not valid"
    );
    require(block.number < nextUpdateBlock, "TimeBasedDistribution: settle pending reward before add new member");

    Member memory member = Member({
      allocation: _allocation,
      lockedAmount: 0,
      releaseAmountPerPeriod: 0,
      effectiveJackpotBlock: block.number
    });
    memberInfo[_memberAddress] = member;
    members.push(_memberAddress);
    totalAllocation = totalAllocation.add(_allocation);

    emit AddMember(_memberAddress, _allocation);
  }

  function distributeReward() external nonReentrant {
    require(block.number >= nextUpdateBlock, "TimeBasedDistribution: no pending reward to be distributed");

    uint256 lockPeriods = shiftNextUpdateBlock(true);
    if (lockPeriods > 0) {
      lockReward(lockPeriods);
    }

    uint256 releasePeriods = shiftNextUpdateBlock(false);
    if (releasePeriods > 0) {
      releaseReward(releasePeriods);
    }

    lastUpdateBlock = block.number;
    emit DistributionInfo(lockPeriods, releasePeriods, nextUpdateBlock);
  }

  function releaseJackpotReward() external nonReentrant {
    require(block.number >= jackpotReleaseBlock, "TimeBasedDistribution: jackpot reward is not release yet");
    require(jackpotReward > 0, "TimeBasedDistribution: no jackpot reward to be distributed");

    uint256 effectiveTotalJackpot = 0;
    uint256 memberLength = members.length;
    uint256[] memory memberWeightList = new uint256[](memberLength);

    for (uint256 i; i < memberLength; i++) {
      address memberAddress = members[i];
      Member memory member = memberInfo[memberAddress];

      uint256 memberEffectivePeriods = jackpotReleaseBlock.sub(member.effectiveJackpotBlock).div(paymentPeriodInBlock);
      uint256 memberWeight = member.allocation.mul(memberEffectivePeriods);

      memberWeightList[i] = memberWeight;
      effectiveTotalJackpot = effectiveTotalJackpot.add(memberWeight);
    }

    for (uint256 i; i < memberLength; i++) {
      address memberAddress = members[i];
      uint256 memberWeight = memberWeightList[i];
      uint256 memberReward = jackpotReward.mul(memberWeight).div(effectiveTotalJackpot);
      token.safeTransfer(memberAddress, memberReward);

      emit ReleaseJackpotReward(memberAddress, memberReward);
    }
    // clear jackpot reward storage
    jackpotReward = 0;
  }

  function lockReward(uint256 periods) internal {
    uint256 totalReward = periods.mul(distributePerPeriod);
    for (uint256 i; i < members.length; i++) {
      address memberAddress = members[i];
      Member storage member = memberInfo[memberAddress];
      uint256 memberReward = totalReward.mul(member.allocation).div(totalAllocation);
      member.lockedAmount = member.lockedAmount.add(memberReward);
      emit LockReward(memberAddress, memberReward);
    }
  }

  function releaseReward(uint256 periods) internal {
    uint256 totalReward = periods.mul(distributePerPeriod);
    for (uint256 i; i < members.length; i++) {
      address memberAddress = members[i];
      Member storage member = memberInfo[memberAddress];

      // for normal release
      uint256 memberReward = totalReward.mul(member.allocation).div(totalAllocation);

      // lock release
      if (member.lockedAmount > 0) {
        // first time relase
        if (member.releaseAmountPerPeriod == 0) {
          member.releaseAmountPerPeriod = member.lockedAmount.div(numberOfLockPeriod);
        }
        uint256 releaseAmount = member.releaseAmountPerPeriod.mul(periods);
        if (releaseAmount > member.lockedAmount) {
          releaseAmount = member.lockedAmount;
        }
        memberReward = memberReward.add(releaseAmount);
        member.lockedAmount = member.lockedAmount.sub(releaseAmount);
      }
      token.safeTransfer(memberAddress, memberReward);
      totalDistributed = totalDistributed.add(memberReward);

      emit ReleaseReward(memberAddress, memberReward);
    }
  }

  function shiftNextUpdateBlock(bool lockPeriod) internal returns (uint256 periods) {
    periods = 0;
    uint256 max = lastReleaseBlock;
    if (lockPeriod == true) {
      max = startReleaseBlock;
    }
    while (nextUpdateBlock < block.number && nextUpdateBlock < max) {
      periods = periods.add(1);
      nextUpdateBlock = nextUpdateBlock.add(paymentPeriodInBlock);
    }
    return periods;
  }

  function removeMemberAllocation(address _memberAddress) external onlyOwner {
    require(_memberAddress != address(0), "TimeBasedDistribution: cannot remove allocation for zero address");
    require(
      block.number < nextUpdateBlock,
      "TimeBasedDistribution: settle pending reward before remove member allocation"
    );

    Member storage member = memberInfo[_memberAddress];

    totalAllocation = totalAllocation.sub(member.allocation);
    member.allocation = 0;

    uint256 lockedAmount = member.lockedAmount;
    jackpotReward = jackpotReward.add(lockedAmount);
    member.lockedAmount = 0;
    
    // delete member from member list
    for (uint256 i = 0; i < members.length; i++) {
      if (members[i] == _memberAddress) {
        members[i] = members[members.length - 1];
        members.pop();
      }
    }

    emit RemoveMemberAllocation(_memberAddress, lockedAmount);
  }

  function updateMemberAllocation(address _memberAddress, uint256 _allocation) external onlyOwner {
    require(_memberAddress != address(0), "TimeBasedDistribution: cannot update allocation for zero address");
    require(
      _allocation >= minAllocation && _allocation <= maxAllocation,
      "TimeBasedDistribution: allocation is not valid"
    );
    require(
      block.number < nextUpdateBlock,
      "TimeBasedDistribution: settle pending reward before update member allocation"
    );

    // Get member instance
    Member storage member = memberInfo[_memberAddress];

    // Clean current allocation from totalAllocation
    totalAllocation = totalAllocation.sub(member.allocation);

    // Assign new allocation
    member.allocation = _allocation;
    totalAllocation = totalAllocation.add(_allocation);

    emit UpdateMemberAllocation(_memberAddress, _allocation);
  }

  function walletInfo()
    external
    view
    returns (
      uint256 firstDistributeBlock,
      uint256 lastDistributeBlock,
      uint256 currentPeriod,
      uint256 distributedPeriod
    )
  {
    firstDistributeBlock = startReleaseBlock.sub(paymentPeriodInBlock.mul(numberOfLockPeriod));
    lastDistributeBlock = firstDistributeBlock.add(paymentPeriodInBlock.mul(distributionTimes));
    currentPeriod = block.number.sub(firstDistributeBlock).div(paymentPeriodInBlock).add(2);
    distributedPeriod = lastUpdateBlock.sub(firstDistributeBlock).div(paymentPeriodInBlock).add(1);
  }

  function memberList() external view returns (address[] memory addrs) {
    address[] memory addrs = new address[](members.length);

    for (uint256 i = 0; i < members.length; i++) {
      addrs[i] = members[i];
    }
    return addrs;
  }
}
