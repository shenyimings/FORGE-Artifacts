// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./interfaces/IStakePool.sol";
import "./interfaces/IStakePoolController.sol";
import "./interfaces/IStakePoolRewardRebaser.sol";
import "./interfaces/IStakePoolRewardMultiplier.sol";
import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import './libraries/TransferHelper.sol';
import "./interfaces/IStakePoolRewardFund.sol";

contract StakePool is IStakePool {
    using SafeMath for uint;
    uint public override version;
    // Info of each user.
    struct UserInfo {
        uint amount;
        mapping(uint8 => uint) rewardDebt;
        mapping(uint8 => uint) reward;
        mapping(uint8 => uint) accumulatedEarned; // will accumulate every time user harvest
        mapping(uint8 => uint) lockReward;
        mapping(uint8 => uint) lockRewardReleased;
        uint lastStakeTime;
    }

    // Info of each rewardPool funding.
    struct RewardPoolInfo {
        address rewardToken;     // Address of rewardPool token contract.
        address rewardRebaser;     // Address of rewardRebaser contract.
        address rewardMultiplier;     // Address of rewardMultiplier contract.
        uint startRewardTime;   // Start reward block number that rewardPool distribution occurs.
        uint lastRewardTime;   // Last block number that rewardPool distribution occurs.
        uint endRewardTime;    // Block time which rewardPool distribution ends.
        uint rewardPerSecond;    // Reward token amount to distribute per block.
        uint accRewardPerShare; // Accumulated rewardPool per share, times 1e18.

        uint lockRewardPercent; // Lock reward percent - 0 to disable lock & vesting
        uint startVestingTime; // Block time which vesting starts.
        uint endVestingTime;   // Block time which vesting ends.
        uint vestingDuration;

        uint totalPaidRewards;
    }

    mapping(address => UserInfo) public userInfo;
    RewardPoolInfo[] public rewardPoolInfo;
    address public override stakeToken;
    address public rewardFund;
    address public timelock;
    address public controller;

    uint public balance;
    uint public unstakingFrozenTime = 3 days;
    uint private unlocked = 1;
    bool private _initialized = false;

    constructor(address _controller, uint _version) public {
        controller = _controller;
        timelock = msg.sender;
        version = _version;
    }
    modifier lock() {
        require(unlocked == 1, 'StakePool: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    modifier onlyTimeLock() {
        require(msg.sender == timelock, "StakePool: !timelock");
        _;
    }

    function allowRecoverRewardToken(address _token) external view override returns (bool) {
        for (uint8 pid = 0; pid < rewardPoolInfo.length; ++pid) {
            RewardPoolInfo storage rewardPool = rewardPoolInfo[pid];
            if (rewardPool.rewardToken == _token) {
                // do not allow to drain reward token if less than 3 days after pool ends
                if (block.timestamp < (rewardPool.endRewardTime + (3 days))) {
                    return false;
                }
            }
        }
        return true;
    }
    // called once by the factory at time of deployment
    function initialize(address _stakeToken, uint _unstakingFrozenTime, address _rewardFund, address _timelock) external override {
        require(_initialized == false, "StakePool: Initialize must be false.");
        require(unstakingFrozenTime <= 30 days, "StakePool: unstakingFrozenTime > 30 days");
        stakeToken = _stakeToken;
        unstakingFrozenTime = _unstakingFrozenTime;
        rewardFund = _rewardFund;
        timelock = _timelock;
        _initialized = true;
    }

    function addRewardPool(
        address _rewardToken, address _rewardRebaser, address _rewardMultiplier,
        uint256 _startTime, uint256 _endRewardTime,
        uint256 _rewardPerSecond, uint256 _lockRewardPercent,
        uint256 _startVestingTime, uint256 _endVestingTime
    ) external override lock onlyTimeLock {
        require(rewardPoolInfo.length <= 16, "StakePool: Reward pool length > 16");
        require(IStakePoolController(controller).isWhitelistRewardRebaser(_rewardRebaser), "StakePool: Invalid reward rebaser");
        require(IStakePoolController(controller).isWhitelistRewardMultiplier(_rewardMultiplier), "StakePool: Invalid reward multiplier");
        require(_startVestingTime <= _endVestingTime, "StakePool: startVestingTime > endVestingTime");
        _startTime = (block.timestamp > _startTime) ? block.timestamp : _startTime;
        require(_startTime < _endRewardTime, "StakePool: startTime >= endRewardTime");
        require(_lockRewardPercent <= 100, "StakePool: invalid lockRewardPercent");
        updateReward();
        rewardPoolInfo.push(RewardPoolInfo({
        rewardToken : _rewardToken,
        rewardRebaser : _rewardRebaser,
        startRewardTime : _startTime,
        rewardMultiplier : _rewardMultiplier,
        lastRewardTime : _startTime,
        endRewardTime : _endRewardTime,
        rewardPerSecond : _rewardPerSecond,
        accRewardPerShare : 0,
        lockRewardPercent : _lockRewardPercent,
        startVestingTime : _startVestingTime,
        endVestingTime : _endVestingTime,
        vestingDuration : _endVestingTime - _startVestingTime,
        totalPaidRewards : 0
        }));
        emit AddRewardPool(rewardPoolInfo.length - 1);
    }

    function updateRewardMultiplier(uint8 _pid, address _rewardMultiplier) external override lock onlyTimeLock {
        require(IStakePoolController(controller).isWhitelistRewardMultiplier(_rewardMultiplier), "StakePool: Invalid reward multiplier");
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        rewardPool.rewardMultiplier = _rewardMultiplier;
        updateReward(_pid);
        emit UpdateRewardMultiplier(_pid, _rewardMultiplier);
    }

    function updateRewardRebaser(uint8 _pid, address _rewardRebaser) external override lock onlyTimeLock {
        require(IStakePoolController(controller).isWhitelistRewardRebaser(_rewardRebaser), "StakePool: Invalid reward rebaser");
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        rewardPool.rewardRebaser = _rewardRebaser;
        updateReward(_pid);
        emit UpdateRewardRebaser(_pid, _rewardRebaser);
    }

    // Return reward multiplier over the given _from to _to block.
    function getRewardMultiplier(uint8 _pid, uint _from, uint _to, uint _rewardPerSecond) public override view returns (uint) {
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        address rewardMultiplier = rewardPool.rewardMultiplier;
        if (rewardMultiplier == address(0)) {
            return _to.sub(_from).mul(_rewardPerSecond);
        }
        return IStakePoolRewardMultiplier(rewardMultiplier).getRewardMultiplier(
            rewardPool.startRewardTime,
            rewardPool.endRewardTime,
            _from,
            _to,
            _rewardPerSecond
        );
    }

    function getRewardRebase(uint8 _pid, address _rewardToken, uint _pendingReward) public override view returns (uint) {
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        address rewardRebaser = rewardPool.rewardRebaser;
        if (rewardRebaser == address(0)) {
            return _pendingReward;
        }
        return IStakePoolRewardRebaser(rewardRebaser).getRebaseAmount(_rewardToken, _pendingReward);
    }

    function getRewardPerSecond(uint8 pid, uint from, uint to) public view returns (uint) {
        RewardPoolInfo storage rewardPool = rewardPoolInfo[pid];
        uint rewardPerSecond = rewardPool.rewardPerSecond;
        if (from < rewardPool.startRewardTime || from > rewardPool.endRewardTime) return 0;
        uint reward = getRewardMultiplier(pid, from, to, rewardPerSecond);
        return getRewardRebase(pid, rewardPool.rewardToken, reward);
    }

    function getRewardPerSecond(uint8 pid) external override view returns (uint) {
        return getRewardPerSecond(pid, block.timestamp, block.timestamp + 1);
    }

    function updateRewardPool(uint8 _pid, uint256 _endRewardTime, uint256 _rewardPerSecond) public override lock onlyTimeLock {
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        require(block.timestamp <= rewardPool.endRewardTime && block.timestamp <= _endRewardTime, "StakePool: blockTime > endRewardTime");
        updateReward(_pid);
        rewardPool.endRewardTime = _endRewardTime;
        rewardPool.rewardPerSecond = _rewardPerSecond;
        emit UpdateRewardPool(_pid, _endRewardTime, _rewardPerSecond);
    }

    function stopRewardPool(uint8 _pid) public override lock onlyTimeLock {
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        updateReward(_pid);
        rewardPool.endRewardTime = block.timestamp;
        rewardPool.rewardPerSecond = 0;
        emit UpdateRewardPool(_pid, rewardPool.endRewardTime, rewardPool.rewardPerSecond);
    }

    function stake(uint _amount) external lock override {
        TransferHelper.safeTransferFrom(stakeToken, msg.sender, address(this), _amount);
        _stakeFor(msg.sender);
    }

    function stakeFor(address _account) external lock override {
        require(IStakePoolController(controller).isWhitelistStakingFor(msg.sender), "StakePool: Invalid sender");
        _stakeFor(_account);
    }

    function _stakeFor(address _account) internal {
        uint _amount = IERC20(stakeToken).balanceOf(address(this)).sub(balance);
        require(_amount > 0, "StakePool: Invalid balance");
        balance = balance.add(_amount);
        UserInfo storage user = userInfo[_account];
        getAllRewards(_account);
        user.amount = user.amount.add(_amount);
        uint8 rewardPoolLength = uint8(rewardPoolInfo.length);
        for (uint8 _pid = 0; _pid < rewardPoolLength; ++_pid) {
            user.rewardDebt[_pid] = user.amount.mul(rewardPoolInfo[_pid].accRewardPerShare).div(1e18);
        }
        user.lastStakeTime = block.timestamp;
        emit Deposit(_account, _amount);
    }

    function rewardPoolInfoLength() public override view returns (uint) {
        return rewardPoolInfo.length;
    }

    function unfrozenStakeTime(address _account) public override view returns (uint) {
        return userInfo[_account].lastStakeTime + unstakingFrozenTime;
    }

    function removeStakeInternal(uint _amount) internal {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "StakePool: invalid withdraw amount");
        require(block.timestamp >= user.lastStakeTime.add(unstakingFrozenTime), "StakePool: frozen");
        getAllRewards(msg.sender);
        balance = balance.sub(_amount);
        user.amount = user.amount.sub(_amount);
        uint8 rewardPoolLength = uint8(rewardPoolInfo.length);
        for (uint8 _pid = 0; _pid < rewardPoolLength; ++_pid) {
            user.rewardDebt[_pid] = user.amount.mul(rewardPoolInfo[_pid].accRewardPerShare).div(1e18);
        }
    }

    function withdraw(uint _amount) public lock override {
        removeStakeInternal(_amount);
        TransferHelper.safeTransfer(stakeToken, msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function exit() external {
        withdraw(userInfo[msg.sender].amount);
    }

    function getAllRewards(address _account) public override {
        uint8 rewardPoolLength = uint8(rewardPoolInfo.length);
        for (uint8 _pid = 0; _pid < rewardPoolLength; ++_pid) {
            getReward(_pid, _account);
        }
    }

    function claimReward() external override {
        getAllRewards(msg.sender);
    }

    function getReward(uint8 _pid, address _account) public override {
        updateReward(_pid);
        UserInfo storage user = userInfo[_account];
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        uint _accRewardPerShare = rewardPool.accRewardPerShare;
        uint _pendingReward = user.amount.mul(_accRewardPerShare).div(1e18).sub(user.rewardDebt[_pid]);
        uint _lockRewardPercent = rewardPool.lockRewardPercent;
        if (_lockRewardPercent > 0) {
            if (block.timestamp > rewardPool.endVestingTime) {
                uint _unlockReward = user.lockReward[_pid].sub(user.lockRewardReleased[_pid]);
                if (_unlockReward > 0) {
                    _pendingReward = _pendingReward.add(_unlockReward);
                    user.lockRewardReleased[_pid] = user.lockRewardReleased[_pid].add(_unlockReward);
                }
            } else {
                if (_pendingReward > 0) {
                    uint _toLocked = _pendingReward.mul(_lockRewardPercent).div(100);
                    _pendingReward = _pendingReward.sub(_toLocked);
                    user.lockReward[_pid] = user.lockReward[_pid].add(_toLocked);
                }
                uint _startVestingTime = rewardPool.startVestingTime;
                if (block.timestamp > _startVestingTime) {
                    uint _toReleased = user.lockReward[_pid].mul(block.timestamp.sub(_startVestingTime)).div(rewardPool.vestingDuration);
                    uint _lockRewardReleased = user.lockRewardReleased[_pid];
                    if (_toReleased > _lockRewardReleased) {
                        uint _unlockReward = _toReleased.sub(_lockRewardReleased);
                        user.lockRewardReleased[_pid] = _lockRewardReleased.add(_unlockReward);
                        _pendingReward = _pendingReward.add(_unlockReward);
                    }
                }
            }
        }
        if (_pendingReward > 0) {
            user.accumulatedEarned[_pid] = user.accumulatedEarned[_pid].add(_pendingReward);
            rewardPool.totalPaidRewards = rewardPool.totalPaidRewards.add(_pendingReward);
            user.rewardDebt[_pid] = user.amount.mul(_accRewardPerShare).div(1e18);
            uint reward = user.reward[_pid].add(_pendingReward);
            user.reward[_pid] = reward;
            // Safe reward transfer, just in case if rounding error causes pool to not have enough reward amount
            address rewardToken = rewardPool.rewardToken;
            uint rewardBalance = IERC20(rewardToken).balanceOf(rewardFund);
            if (rewardBalance > 0) {
                user.reward[_pid] = 0;
                uint rebaseAmount = getRewardRebase(_pid, rewardToken, reward);
                uint paidAmount = rebaseAmount > rewardBalance ? rewardBalance : rebaseAmount;
                IStakePoolRewardFund(rewardFund).safeTransfer(rewardToken, _account, paidAmount);
                emit PayRewardPool(_pid, rewardToken, _account, reward, rebaseAmount, paidAmount);
            }
        }
    }


    function pendingReward(uint8 _pid, address _account) external override view returns (uint) {
        UserInfo storage user = userInfo[_account];
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        uint _accRewardPerShare = rewardPool.accRewardPerShare;
        uint lpSupply = IERC20(stakeToken).balanceOf(address(this));
        uint _endRewardTime = rewardPool.endRewardTime;
        uint _endRewardTimeApplicable = block.timestamp > _endRewardTime ? _endRewardTime : block.timestamp;
        uint _lastRewardTime = rewardPool.lastRewardTime;
        if (_endRewardTimeApplicable > _lastRewardTime && lpSupply != 0) {
            uint _incRewardPerShare = getRewardMultiplier(_pid, _lastRewardTime, _endRewardTimeApplicable, rewardPool.rewardPerSecond).mul(1e18).div(lpSupply);
            _accRewardPerShare = _accRewardPerShare.add(_incRewardPerShare);
        }
        uint pending = user.amount.mul(_accRewardPerShare).div(1e18).add(user.reward[_pid]).sub(user.rewardDebt[_pid]);
        return getRewardRebase(_pid, rewardPool.rewardToken, pending);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() external lock override {
        require(unstakingFrozenTime == 0 || IStakePoolController(controller).isAllowEmergencyWithdrawStakePool(address(this)), "StakePool: Not allow emergencyWithdraw");
        UserInfo storage user = userInfo[msg.sender];
        uint amount = user.amount;
        balance = balance.sub(amount);
        user.amount = 0;
        TransferHelper.safeTransfer(stakeToken, msg.sender, amount);
        uint8 rewardPoolLength = uint8(rewardPoolInfo.length);
        for (uint8 _pid = 0; _pid < rewardPoolLength; ++_pid) {
            user.rewardDebt[_pid] = 0;
            user.reward[_pid] = 0;
        }
    }

    function getUserInfo(uint8 _pid, address _account) public override view returns (uint amount, uint rewardDebt, uint accumulatedEarned, uint lockReward, uint lockRewardReleased) {
        UserInfo storage user = userInfo[_account];
        amount = user.amount;
        rewardDebt = user.rewardDebt[_pid];
        accumulatedEarned = user.accumulatedEarned[_pid];
        lockReward = user.lockReward[_pid];
        lockRewardReleased = user.lockRewardReleased[_pid];
    }

    function updateReward() public override {
        uint8 rewardPoolLength = uint8(rewardPoolInfo.length);
        for (uint8 _pid = 0; _pid < rewardPoolLength; ++_pid) {
            updateReward(_pid);
        }
    }

    function updateReward(uint8 _pid) public override {
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_pid];
        uint _endRewardTime = rewardPool.endRewardTime;
        uint _endRewardTimeApplicable = block.timestamp > _endRewardTime ? _endRewardTime : block.timestamp;
        uint _lastRewardTime = rewardPool.lastRewardTime;
        if (_endRewardTimeApplicable > _lastRewardTime) {
            uint lpSupply = IERC20(stakeToken).balanceOf(address(this));
            if (lpSupply > 0) {
                uint _incRewardPerShare = getRewardMultiplier(_pid, _lastRewardTime, _endRewardTimeApplicable, rewardPool.rewardPerSecond).mul(1e18).div(lpSupply);
                rewardPool.accRewardPerShare = rewardPool.accRewardPerShare.add(_incRewardPerShare);
            }
            rewardPool.lastRewardTime = _endRewardTimeApplicable;
        }
    }

}
