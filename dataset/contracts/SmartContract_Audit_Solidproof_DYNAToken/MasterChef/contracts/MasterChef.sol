// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import './interfaces/IBEP20.sol';
import './interfaces/IDYNAReferral.sol';
import './interfaces/IFeeStrategy.sol';
import './utils/SafeBEP20.sol';
import './DYNAToken.sol';

// MasterChef is the master of Dyna. He can make Dyna and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once DYNA is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeBEP20 for IBEP20;

  // Info of each user.
  struct UserInfo {
    uint256 amount;         // How many LP tokens the user has provided.
    uint256 rewardDebt;     // Reward debt. See explanation below.
    uint256 rewardLockedUp;  // Reward locked up.
    uint256 nextHarvestUntil; // When can the user harvest again.
    //
    // We do some fancy math here. Basically, any point in time, the amount of DYNAs
    // entitled to a user but is pending to be distributed is:
    //
    //   pending reward = (user.amount * pool.accDynaPerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    //   1. The pool's `accDynaPerShare` (and `lastRewardTimestamp`) gets updated.
    //   2. User receives the pending reward sent to his/her address.
    //   3. User's `amount` gets updated.
    //   4. User's `rewardDebt` gets updated.
  }

  // Info of each pool.
  struct PoolInfo {
    IBEP20 lpToken;           // Address of LP token contract.
    uint256 allocPoint;       // How many allocation points assigned to this pool. DYNAs to distribute per block.
    uint256 lastRewardTimestamp;  // Last timestamp that DYNAs distribution occurs.
    uint256 accDynaPerShare;   // Accumulated DYNAs per share, times 1e12. See below.
    uint16 depositFeeBP;      // Deposit fee in basis points
    uint256 harvestInterval;  // Harvest interval in seconds
  }

  // The DYNA TOKEN!
  DYNAToken public dyna;
  // Buyback address
  address public buybackAddress;
  // Dev address.
  address public devAddress;
  // Deposit Fee address
  address public feeAddress;
  // DYNA tokens created per second.
  uint256 public dynaPerSec;
  // Bonus muliplier for early dyna makers.
  uint256 public constant BONUS_MULTIPLIER = 1;
  // Max harvest interval: 14 days.
  uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;
  // fee distribution rates
  uint16 public constant BUYBACK_RATE = 8000; // 80% of deposit fee
  uint16 public constant DEV_FEE_RATE = 1000; // 10% of deposit fee
  uint16 public constant HOLDING_FEE_RATE = 1000; // 10% of deposit fee

  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint = 0;
  // The block number when DYNA mining starts.
  uint256 public startTimestamp;
  // Total locked up rewards
  uint256 public totalLockedUpRewards;

  // Dyna fee duduction strategy address.
  IFeeStrategy public feeStrategy;

  // Dyna referral contract address.
  IDYNAReferral public dynaReferral;
  // Referral commission rate in basis points.
  uint16 public referralCommissionRate = 100;
  // Max referral commission rate: 10%.
  uint16 public constant MAXIMUM_REFERRAL_COMMISSION_RATE = 1000;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
  event ReferralCommissionPaid(address indexed user, address indexed referrer, uint256 commissionAmount);
  event RewardLockedUp(address indexed user, uint256 indexed pid, uint256 amountLockedUp);

  constructor(
    DYNAToken _dyna,
    uint256 _startTimestamp,
    uint256 _dynaPerSec,
    address _feeStrategy
  ) public {
    dyna = _dyna;
    startTimestamp = _startTimestamp;
    dynaPerSec = _dynaPerSec;

    devAddress = msg.sender;
    feeAddress = msg.sender;
    buybackAddress = msg.sender;

    feeStrategy = IFeeStrategy(_feeStrategy);
  }

  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  // Add a new lp to the pool. Can only be called by the owner.
  // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
  function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, uint256 _harvestInterval, bool _withUpdate) external onlyOwner {
    require(_depositFeeBP <= 10000, 'add: invalid deposit fee basis points');
    require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, 'add: invalid harvest interval');
    if (_withUpdate) {
      massUpdatePools();
    }
    uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(PoolInfo({
      lpToken: _lpToken,
      allocPoint: _allocPoint,
      lastRewardTimestamp: lastRewardTimestamp,
      accDynaPerShare: 0,
      depositFeeBP: _depositFeeBP,
      harvestInterval: _harvestInterval
    }));
  }

  // Update the given pool's DYNA allocation point and deposit fee. Can only be called by the owner.
  function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, uint256 _harvestInterval, bool _withUpdate) external onlyOwner {
    require(_depositFeeBP <= 10000, 'set: invalid deposit fee basis points');
    require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, 'set: invalid harvest interval');
    if (_withUpdate) {
      massUpdatePools();
    }
    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
    poolInfo[_pid].allocPoint = _allocPoint;
    poolInfo[_pid].depositFeeBP = _depositFeeBP;
    poolInfo[_pid].harvestInterval = _harvestInterval;
  }

  // Return reward multiplier over the given _from to _to block.
  function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
    return _to.sub(_from).mul(BONUS_MULTIPLIER);
  }

  // View function to see pending DYNAs on frontend.
  function pendingDyna(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accDynaPerShare = pool.accDynaPerShare;
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
      uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
      uint256 dynaReward = multiplier.mul(dynaPerSec).mul(pool.allocPoint).div(totalAllocPoint);
      accDynaPerShare = accDynaPerShare.add(dynaReward.mul(1e12).div(lpSupply));
    }
    uint256 pending = user.amount.mul(accDynaPerShare).div(1e12).sub(user.rewardDebt);
    return pending.add(user.rewardLockedUp);
  }

  // View function to see if user can harvest DYNAs.
  function canHarvest(uint256 _pid, address _user) public view returns (bool) {
    UserInfo storage user = userInfo[_pid][_user];
    return block.timestamp >= user.nextHarvestUntil;
  }

  // Update reward variables for all pools. Be careful of gas spending!
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  // Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    if (block.timestamp <= pool.lastRewardTimestamp) {
      return;
    }
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (lpSupply == 0 || pool.allocPoint == 0) {
      pool.lastRewardTimestamp = block.timestamp;
      return;
    }
    uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
    uint256 dynaReward = multiplier.mul(dynaPerSec).mul(pool.allocPoint).div(totalAllocPoint);
    // dyna.mint(devAddress, dynaReward.div(10));
    dyna.mint(address(this), dynaReward);
    pool.accDynaPerShare = pool.accDynaPerShare.add(dynaReward.mul(1e12).div(lpSupply));
    pool.lastRewardTimestamp = block.timestamp;
  }

  // Deposit LP tokens to MasterChef for DYNA allocation.
  function deposit(uint256 _pid, uint256 _amount, address _referrer) external nonReentrant {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    if (_amount > 0 && address(dynaReferral) != address(0) && _referrer != address(0) && _referrer != msg.sender) {
      dynaReferral.recordReferral(msg.sender, _referrer);
    }
    payOrLockupPendingDyna(_pid);
    if (_amount > 0) {
      pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
      // if (address(pool.lpToken) == address(dyna)) {
      //     uint256 transferTax = _amount.mul(dyna.transferTaxRate()).div(10000);
      //     _amount = _amount.sub(transferTax);
      // }
      if (pool.depositFeeBP > 0) {
        uint256 depositFeeRate = feeStrategy.getExactFarmDepositFeeBPForDynaHolder(pool.depositFeeBP, msg.sender);
        uint256 depositFee = _amount.mul(depositFeeRate).div(10000);
        uint256 buybackFee = depositFee.mul(BUYBACK_RATE).div(10000);
        uint256 devFee = depositFee.mul(DEV_FEE_RATE).div(10000);
        uint holdingFee = depositFee.mul(HOLDING_FEE_RATE).div(10000);

        require(buybackFee.add(devFee).add(holdingFee) == depositFee, 'DYNA: fee distribution mismatch');

        pool.lpToken.safeTransfer(buybackAddress, buybackFee);
        pool.lpToken.safeTransfer(devAddress, devFee);
        pool.lpToken.safeTransfer(feeAddress, holdingFee);

        user.amount = user.amount.add(_amount).sub(depositFee);
      } else {
        user.amount = user.amount.add(_amount);
      }
    }
    user.rewardDebt = user.amount.mul(pool.accDynaPerShare).div(1e12);
    emit Deposit(msg.sender, _pid, _amount);
  }

  // Withdraw LP tokens from MasterChef.
  function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, 'withdraw: not good');
    updatePool(_pid);
    payOrLockupPendingDyna(_pid);
    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      pool.lpToken.safeTransfer(address(msg.sender), _amount);
    }
    user.rewardDebt = user.amount.mul(pool.accDynaPerShare).div(1e12);
    emit Withdraw(msg.sender, _pid, _amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) external nonReentrant {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    uint256 amount = user.amount;
    user.amount = 0;
    user.rewardDebt = 0;
    user.rewardLockedUp = 0;
    user.nextHarvestUntil = 0;
    pool.lpToken.safeTransfer(address(msg.sender), amount);
    emit EmergencyWithdraw(msg.sender, _pid, amount);
  }

  // Pay or lockup pending DYNAs.
  function payOrLockupPendingDyna(uint256 _pid) internal {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    if (user.nextHarvestUntil == 0) {
      user.nextHarvestUntil = block.timestamp.add(pool.harvestInterval);
    }

    uint256 pending = user.amount.mul(pool.accDynaPerShare).div(1e12).sub(user.rewardDebt);
    if (canHarvest(_pid, msg.sender)) {
      if (pending > 0 || user.rewardLockedUp > 0) {
        uint256 totalRewards = pending.add(user.rewardLockedUp);

        // reset lockup
        totalLockedUpRewards = totalLockedUpRewards.sub(user.rewardLockedUp);
        user.rewardLockedUp = 0;
        user.nextHarvestUntil = block.timestamp.add(pool.harvestInterval);

        // send rewards
        safeDynaTransfer(msg.sender, totalRewards);
        payReferralCommission(msg.sender, totalRewards);
      }
    } else if (pending > 0) {
      user.rewardLockedUp = user.rewardLockedUp.add(pending);
      totalLockedUpRewards = totalLockedUpRewards.add(pending);
      emit RewardLockedUp(msg.sender, _pid, pending);
    }
  }

  // Safe dyna transfer function, just in case if rounding error causes pool to not have enough DYNAs.
  function safeDynaTransfer(address _to, uint256 _amount) internal {
    uint256 dynaBal = dyna.balanceOf(address(this));
    if (_amount > dynaBal) {
      dyna.transfer(_to, dynaBal);
    } else {
      dyna.transfer(_to, _amount);
    }
  }

  // Update dev address by the previous dev.
  function setDevAddress(address _devAddress) external {
    require(msg.sender == devAddress, 'setDevAddress: FORBIDDEN');
    require(_devAddress != address(0), 'setDevAddress: ZERO');
    devAddress = _devAddress;
  }

  function setFeeAddress(address _feeAddress) external {
    require(msg.sender == feeAddress, 'setFeeAddress: FORBIDDEN');
    require(_feeAddress != address(0), 'setFeeAddress: ZERO');
    feeAddress = _feeAddress;
  }

  function setBuybackAddress(address _buybackAddress) external {
    require(msg.sender == buybackAddress, 'setBuybackAddress: FORBIDDEN');
    require(_buybackAddress != address(0), 'setBuybackAddress: ZERO');
    buybackAddress = _buybackAddress;
  }

  // Pancake has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
  function updateEmissionRate(uint256 _dynaPerSec) external onlyOwner {
    massUpdatePools();
    emit EmissionRateUpdated(msg.sender, dynaPerSec, _dynaPerSec);
    dynaPerSec = _dynaPerSec;
  }

  // Update the dyna referral contract address by the owner
  function setDynaReferral(IDYNAReferral _dynaReferral) external onlyOwner {
    dynaReferral = _dynaReferral;
  }

  // Update referral commission rate by the owner
  function setReferralCommissionRate(uint16 _referralCommissionRate) external onlyOwner {
    require(_referralCommissionRate <= MAXIMUM_REFERRAL_COMMISSION_RATE, 'setReferralCommissionRate: invalid referral commission rate basis points');
    referralCommissionRate = _referralCommissionRate;
  }

  function setFeeStrategy(address _feeStrategy) external onlyOwner {
    feeStrategy = IFeeStrategy(_feeStrategy);
  }

  // Pay referral commission to the referrer who referred this user.
  function payReferralCommission(address _user, uint256 _pending) internal {
    if (address(dynaReferral) != address(0) && referralCommissionRate > 0) {
      address referrer = dynaReferral.getReferrer(_user);
      uint256 commissionAmount = _pending.mul(referralCommissionRate).div(10000);

      if (referrer != address(0) && commissionAmount > 0) {
        dyna.mint(referrer, commissionAmount);
        dynaReferral.recordReferralCommission(referrer, commissionAmount);
        emit ReferralCommissionPaid(_user, referrer, commissionAmount);
      }
    }
  }
}
