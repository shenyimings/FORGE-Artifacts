// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IStakingPool2.sol";
import "../utils/Ownable.sol";
import "../libraries/TransferHelper.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract StakingPool2 is IStakingPool2, Ownable, Initializable {
    struct RewardState {
        uint256 index;
        uint256 timestamp;
    }

    struct FixedDeposit {
        uint256 amount;
        uint256 shares;
    }

    uint256 public constant ONE_YEAR = 365 * 24 * 3600;
    uint256 public constant INDEX_SCALE = 1e36;
    uint256 public constant EXPIRE_MAPPING_HEAD = uint256(1);

    uint256 public override rewardsPerSecond;
    uint256 public override endTime;
    uint256 public override minPeriod;
    uint256 public override totalShares;

    address public override stakeToken;
    address public override rewardToken;

    RewardState public override poolRewardState;

    mapping(address => uint256) public override getUserShares;
    mapping(address => uint256) public override getUserIndex;
    mapping(address => uint256) public override getUserCurrentDeposit;
    mapping(address => uint256) public override getUserRewardAccrued;

    mapping(address => mapping(uint256 => uint256)) public getUserNextExpireAt;
    mapping(address => mapping(uint256 => FixedDeposit)) public getUserFixedDeposit;

    function initialize(
        address _owner,
        address _stakeToken,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _endTime,
        uint256 _minPeriod
    ) external initializer {
        owner = _owner;
        stakeToken = _stakeToken;
        rewardToken = _rewardToken;
        rewardsPerSecond = _rewardPerSecond;
        endTime = _endTime;
        minPeriod = _minPeriod;
        poolRewardState = RewardState(INDEX_SCALE, block.timestamp);
    }

    function updateRewardsPerSecond(uint256 newRewardsPerSecond) external onlyOwner {
        emit RewardsPerSecondUpdated(rewardsPerSecond, newRewardsPerSecond);
        rewardsPerSecond = newRewardsPerSecond;
    }

    function updateEndTime(uint256 newEndTime) external onlyOwner {
        emit EndTimeUpdated(endTime, newEndTime);
        endTime = newEndTime;
    }

    function updateMinPeriod(uint256 newMinPeriod) external onlyOwner {
        emit MinPeriodUpdated(minPeriod, newMinPeriod);
        minPeriod = newMinPeriod;
    }

    function rewardClaimable(address user) public view override returns (uint256) {
        uint256 poolIndex;
        uint256 deltaTime = block.timestamp - poolRewardState.timestamp;
        if (deltaTime > 0 && rewardsPerSecond > 0) {
            uint256 rewardsAccrued = deltaTime * rewardsPerSecond;
            uint256 ratio = totalShares > 0 ? (rewardsAccrued * INDEX_SCALE) / totalShares : 0;
            poolIndex = poolRewardState.index + ratio;
        }

        uint256 userIndex = getUserIndex[user];
        if (userIndex == 0 && poolIndex >= INDEX_SCALE) {
            userIndex = INDEX_SCALE;
        }

        uint256 deltaIndex = poolIndex - userIndex;
        uint256 userShares = getUserShares[user];
        uint256 userRewardDelta = (deltaIndex * userShares) / INDEX_SCALE;
        return getUserRewardAccrued[user] + userRewardDelta;
    }

    function withdrawable(address user) public view override returns (uint256) {
        uint256 _addToCurrent;
        uint256 currentTime = block.timestamp;
        uint256 next = getUserNextExpireAt[msg.sender][EXPIRE_MAPPING_HEAD];
        while (next < currentTime && next > 0) {
            _addToCurrent += getUserFixedDeposit[user][next].amount;
            next = getUserNextExpireAt[msg.sender][next];
        }

        return getUserCurrentDeposit[user] + _addToCurrent;
    }

    function currentDeposit(uint256 amount) external override {
        require(amount > 0, "zero amount");

        _updatePoolRewardIndex();
        _distributeUserReward(msg.sender);
        _updateExpiredFixedsToCurrent(msg.sender);

        TransferHelper.safeTransferFrom(stakeToken, msg.sender, address(this), amount);
        _mintShares(msg.sender, amount);
        getUserCurrentDeposit[msg.sender] += amount;
        emit Deposited(msg.sender, amount, amount, 0, 0);
    }

    function fixedDeposit(uint256 amount, uint256 period, uint256 preExpireAt) external override {
        require(amount > 0, "zero amount");
        require(period >= minPeriod, "period less than min period");
        require(preExpireAt > 0, "zero preExpireAt");

        uint256 expireAt = block.timestamp + period;
        require(expireAt <= endTime, "expireAt over endTime");
        require(expireAt > preExpireAt, "expireAt not after preExpireAt");

        _updatePoolRewardIndex();
        _distributeUserReward(msg.sender);
        _updateExpiredFixedsToCurrent(msg.sender);

        TransferHelper.safeTransferFrom(stakeToken, msg.sender, address(this), amount);
        uint256 shares = amount + (amount * 3 * period) / ONE_YEAR;
        _mintShares(msg.sender, shares);

        getUserFixedDeposit[msg.sender][expireAt] = FixedDeposit(amount, shares);
        uint256 first = getUserNextExpireAt[msg.sender][EXPIRE_MAPPING_HEAD];
        if (first == 0) {
            getUserNextExpireAt[msg.sender][EXPIRE_MAPPING_HEAD] = expireAt;
        } else {
            if (preExpireAt == EXPIRE_MAPPING_HEAD) {
                require(expireAt < first, "expireAt not before first");
                getUserNextExpireAt[msg.sender][EXPIRE_MAPPING_HEAD] = expireAt;
                getUserNextExpireAt[msg.sender][expireAt] = first;
            } else {
                require(getUserFixedDeposit[msg.sender][preExpireAt].amount > 0, "invalid preExpireAt");
                uint256 next = getUserNextExpireAt[msg.sender][preExpireAt];
                if (next > 0) require(expireAt < next, "expireAt not before next");
                getUserNextExpireAt[msg.sender][preExpireAt] = expireAt;
                if (next > 0) getUserNextExpireAt[msg.sender][expireAt] = next;
            }
        }

        emit Deposited(msg.sender, amount, shares, period, expireAt);
    }

    function withdraw(address to, uint256 amount) external override {
        _updatePoolRewardIndex();
        _distributeUserReward(msg.sender);
        _updateExpiredFixedsToCurrent(msg.sender);

        require(amount > 0, "zero amount");
        require(amount <= getUserCurrentDeposit[msg.sender], "over withdrawable");
        _burnShares(msg.sender, amount);
        getUserCurrentDeposit[msg.sender] -= amount;

        TransferHelper.safeTransfer(stakeToken, to, amount);
        emit Withdrawn(msg.sender, to, amount);
    }

    function claimReward(address to) external override returns (uint256 claimed) {
        _updatePoolRewardIndex();
        _distributeUserReward(msg.sender);
        _updateExpiredFixedsToCurrent(msg.sender);

        claimed = getUserRewardAccrued[msg.sender];
        require(claimed > 0, "claimable amount is zero");
        getUserRewardAccrued[msg.sender] = 0;

        TransferHelper.safeTransfer(rewardToken, to, claimed);
        emit RewardClaimed(msg.sender, to, claimed);
    }

    function _updatePoolRewardIndex() internal {
        uint256 deltaTime = block.timestamp - poolRewardState.timestamp;
        if (deltaTime > 0 && rewardsPerSecond > 0) {
            uint256 rewardsAccrued = deltaTime * rewardsPerSecond;
            uint256 ratio = totalShares > 0 ? (rewardsAccrued * INDEX_SCALE) / totalShares : 0;
            poolRewardState.index = poolRewardState.index + ratio;
            poolRewardState.timestamp = block.timestamp;
        } else if (deltaTime > 0) {
            poolRewardState.timestamp = block.timestamp;
        }
    }

    function _distributeUserReward(address user) internal {
        uint256 poolIndex = poolRewardState.index;
        uint256 userIndex = getUserIndex[user];
        // Update user's index to the current pool index
        getUserIndex[user] = poolIndex;

        if (userIndex == 0 && poolIndex >= INDEX_SCALE) {
            userIndex = INDEX_SCALE;
        }

        uint256 deltaIndex = poolIndex - userIndex;
        uint256 userShares = getUserShares[user];
        uint256 userRewardDelta = (deltaIndex * userShares) / INDEX_SCALE;
        getUserRewardAccrued[user] += userRewardDelta;

        emit DistributedUserReward(user, userRewardDelta, poolIndex);
    }

    function _updateExpiredFixedsToCurrent(address user) internal {
        FixedDeposit memory _fixed;
        uint256 _addToCurrent;
        uint256 _sharesToBurn;
        uint256 currentTime = block.timestamp;
        uint256 next = getUserNextExpireAt[user][EXPIRE_MAPPING_HEAD];
        uint256 _temp;
        while (next < currentTime && next > 0) {
            _fixed = getUserFixedDeposit[user][next];
            _addToCurrent += _fixed.amount;
            _sharesToBurn += _fixed.shares - _fixed.amount;
            delete getUserFixedDeposit[user][next];

            _temp = next;
            next = getUserNextExpireAt[user][next];
            delete getUserNextExpireAt[user][_temp];
        }

        if (getUserNextExpireAt[user][EXPIRE_MAPPING_HEAD] != next)
            getUserNextExpireAt[user][EXPIRE_MAPPING_HEAD] = next;
        if (_addToCurrent > 0) getUserCurrentDeposit[user] += _addToCurrent;
        if (_sharesToBurn > 0) _burnShares(user, _sharesToBurn);
    }

    function _mintShares(address user, uint256 shares) internal {
        totalShares += shares;
        getUserShares[user] += shares;
        emit SharesTransferred(address(0), user, shares);
    }

    function _burnShares(address user, uint256 shares) internal {
        require(getUserShares[user] >= shares, "not enough shares to be burnt");
        totalShares -= shares;
        getUserShares[user] -= shares;
        emit SharesTransferred(user, address(0), shares);
    }
}
