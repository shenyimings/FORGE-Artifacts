// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SingleStake is AccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address payable;

    uint256 public constant MAX_STAKE_TIME = 4 weeks;
    uint256 public constant STAKING_ROUND_DURATION = 1 weeks;
    uint256 public immutable startTime;
    uint256 public endTime;
    uint256 public rewardsPerSecond;
    uint256 public accPlsPerHeartBeat;
    uint256 public lastRewardTime;
    uint256 public totalHeartBeats;
    IERC20 public constant BRATE =
        IERC20(0x62959f4A9D771dE322c4a52CaA9BaBd1874DEb53);
    mapping(uint256 => StakeData) public stakes;
    mapping(address => UserInfo) private users;
    uint256 public totalStakesCount;
    uint256 public totalBRATEStaked;
    uint256 public totalPLSClaimed;

    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    struct StakeData {
        uint256 id;
        address owner;
        uint256 stakeTime;
        uint256 duration;
        uint256 stakeEndTime;
        uint256 stakeWithdrawTime;
        uint256 amount;
        uint256 claimed;
        uint256 heartBeat;
        uint256 lastUpdate;
        uint256 lastClaim;
        uint256 rewardDebt;
    }
    struct StakeView {
        uint256 id;
        address owner;
        uint256 stakeTime;
        uint256 duration;
        uint256 stakeEndTime;
        uint256 stakeWithdrawTime;
        uint256 amount;
        uint256 claimed;
        uint256 heartBeat;
        uint256 lastUpdate;
        uint256 lastClaim;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }
    struct UserInfo {
        EnumerableSet.UintSet activeStakes;
        EnumerableSet.UintSet endedStakes;
        uint256 claimed;
        uint256 staked;
        uint256 lastDepositTime;
        uint256 lastClaimTime;
        uint256 lastWithdrawTime;
        uint256 totalHeartBeat;
    }

    constructor() {
        startTime = block.timestamp;
        endTime = block.timestamp;
        lastRewardTime = block.timestamp;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(CALLER_ROLE, _msgSender());
    }

    function stopReward() public onlyRole(CALLER_ROLE) {
        uint256 multiplier = getMultiplier(block.timestamp, endTime);
        uint256 tokenReward = multiplier.mul(rewardsPerSecond);
        payable(_msgSender()).sendValue(tokenReward);

        endTime = block.timestamp;
    }

    function deposit(uint256 _amount, uint256 _weeks) public nonReentrant {
        require(_amount != 0, "invalid amount");
        uint256 _duration = _weeks * STAKING_ROUND_DURATION;
        require(_weeks != 0 && _duration <= MAX_STAKE_TIME, "invalid time");
        UserInfo storage user = users[_msgSender()];
        updateAccPLSPerHeartBeat();
        BRATE.safeTransferFrom(_msgSender(), address(this), _amount);
        uint256 _stakeEndTime = block.timestamp + _duration;
        uint256 _heartBeat = _weeks * _amount;
        uint256 _rewardDebt = _heartBeat.mul(accPlsPerHeartBeat).div(1e18);
        totalHeartBeats += _heartBeat;
        uint256 stakeID = totalStakesCount;
        StakeData memory newStake = StakeData({
            id: stakeID,
            owner: _msgSender(),
            stakeTime: block.timestamp,
            duration: _duration,
            stakeEndTime: _stakeEndTime,
            stakeWithdrawTime: 0,
            amount: _amount,
            claimed: 0,
            heartBeat: _heartBeat,
            lastUpdate: block.timestamp,
            lastClaim: 0,
            rewardDebt: _rewardDebt
        });
        stakes[stakeID] = newStake;
        user.activeStakes.add(stakeID);
        user.staked += _amount;
        user.lastDepositTime = block.timestamp;
        user.totalHeartBeat += _heartBeat;
        totalBRATEStaked += _amount;
        totalStakesCount++;
    }

    function _endStake(uint256 _stakeID) private {
        StakeData storage stake = stakes[_stakeID];
        UserInfo storage user = users[_msgSender()];
        require(_msgSender() == stake.owner, "Not the owner");
        require(
            users[_msgSender()].activeStakes.contains(_stakeID),
            "Invalid stake number"
        );
        require(
            block.timestamp >= stake.stakeEndTime,
            "Staking duration has not ended"
        );
        updateAccPLSPerHeartBeat();
        uint256 pendingRewards = pendingPLS(_stakeID);
        require(
            address(this).balance >= pendingRewards,
            "Insufficient PLS balance"
        );
        uint256 amount = stake.amount;
        uint256 heartbeat = stake.heartBeat;
        stake.claimed += pendingRewards;
        totalHeartBeats -= heartbeat;
        stake.heartBeat = 0;
        stake.amount = 0;
        stake.rewardDebt = heartbeat.mul(accPlsPerHeartBeat).div(1e18);
        stake.stakeWithdrawTime = block.timestamp;
        stake.lastClaim = block.timestamp;
        stake.lastUpdate = block.timestamp;
        user.activeStakes.remove(_stakeID);
        user.endedStakes.add(_stakeID);
        user.claimed += pendingRewards;
        user.staked -= amount;
        user.lastClaimTime = block.timestamp;
        user.lastWithdrawTime = block.timestamp;
        user.totalHeartBeat -= heartbeat;
        totalBRATEStaked -= amount;
        totalPLSClaimed += pendingRewards;
        BRATE.safeTransfer(_msgSender(), amount);
        payable(_msgSender()).sendValue(pendingRewards);
    }

    function _claimRewards(uint256 _stakeID) private {
        StakeData storage stake = stakes[_stakeID];
        UserInfo storage user = users[_msgSender()];
        require(_msgSender() == stake.owner, "Not the owner");
        require(
            users[_msgSender()].activeStakes.contains(_stakeID),
            "Invalid stake number"
        );
        updateAccPLSPerHeartBeat();
        uint256 pendingRewards = pendingPLS(_stakeID);
        require(
            address(this).balance >= pendingRewards,
            "Insufficient PLS balance"
        );
        stake.claimed += pendingRewards;
        stake.lastUpdate = block.timestamp;
        stake.lastClaim = block.timestamp;
        stake.rewardDebt = stake.heartBeat.mul(accPlsPerHeartBeat).div(1e18);
        user.claimed += pendingRewards;
        user.lastClaimTime = block.timestamp;
        totalPLSClaimed += pendingRewards;
        payable(_msgSender()).sendValue(pendingRewards);
    }

    function claimRewards(uint256 _stakeNumber) external nonReentrant {
        _claimRewards(_stakeNumber);
    }

    function endStake(uint256 _stakeNumber) external nonReentrant {
        _endStake(_stakeNumber);
    }

    function endAllStakes() public nonReentrant {
        EnumerableSet.UintSet storage activeStakes = users[_msgSender()]
            .activeStakes;
        for (uint256 i = activeStakes.length(); i > 0; i--) {
            uint256 stakeID = activeStakes.at(i - 1);
            if (block.timestamp >= stakes[stakeID].stakeEndTime) {
                _endStake(stakeID);
            }
        }
    }

    function claimAllStakes() public nonReentrant {
        EnumerableSet.UintSet storage activeStakes = users[_msgSender()]
            .activeStakes;

        for (uint256 i = 0; i < activeStakes.length(); i++) {
            uint256 stakeID = activeStakes.at(i);
            _claimRewards(stakeID);
        }
    }

    function updateAccPLSPerHeartBeat() public {
        if (block.timestamp <= lastRewardTime) {
            return;
        }
        if (totalHeartBeats == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(lastRewardTime, block.timestamp);
        uint256 tokenReward = multiplier.mul(rewardsPerSecond);
        accPlsPerHeartBeat = accPlsPerHeartBeat.add(
            tokenReward.mul(1e18).div(totalHeartBeats)
        );
        lastRewardTime = block.timestamp;
    }

    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        if (_to <= endTime) {
            return _to.sub(_from);
        } else if (_from >= endTime) {
            return 0;
        } else {
            return endTime.sub(_from);
        }
    }

    function injectRewardsWithTime(
        uint256 rewardsSeconds
    ) public payable onlyRole(CALLER_ROLE) {
        require(msg.value > 0, "pls missing");
        _injectRewardsWithTime(msg.value, rewardsSeconds);
    }

    function _injectRewardsWithTime(
        uint256 amount,
        uint256 rewardsSeconds
    ) internal {
        updateAccPLSPerHeartBeat();
        uint256 remainingSeconds = endTime > block.timestamp
            ? endTime.sub(block.timestamp)
            : 0;
        uint256 remainingBal = rewardsPerSecond.mul(remainingSeconds);
        if (remainingBal > 0) {
            rewardsSeconds = rewardsSeconds.add(remainingSeconds);
        }
        remainingBal = remainingBal.add(amount);
        rewardsPerSecond = remainingBal.div(rewardsSeconds);
        if (block.timestamp >= startTime) {
            endTime = block.timestamp.add(rewardsSeconds);
        } else {
            endTime = startTime.add(rewardsSeconds);
        }
    }

    function getUserPendingPLSAllStakes(
        address _user
    ) public view returns (uint256 totalPendingPLS) {
        EnumerableSet.UintSet storage activeStakes = users[_user].activeStakes;

        for (uint256 i = 0; i < activeStakes.length(); i++) {
            uint256 stakeID = activeStakes.at(i);
            totalPendingPLS += pendingPLS(stakeID);
        }
    }

    function pendingPLS(uint256 _stakeID) public view returns (uint256) {
        StakeData memory stake = stakes[_stakeID];
        address owner = stake.owner;
        EnumerableSet.UintSet storage endedStakes = users[owner].endedStakes;

        if (EnumerableSet.contains(endedStakes, _stakeID)) {
            return 0;
        }

        uint256 _accPlsPerHeartBeat = accPlsPerHeartBeat;
        uint256 _totalHeartBeats = totalHeartBeats;

        if (block.timestamp > lastRewardTime && _totalHeartBeats != 0) {
            uint256 multiplier = getMultiplier(lastRewardTime, block.timestamp);
            uint256 tokenReward = multiplier.mul(rewardsPerSecond);
            _accPlsPerHeartBeat = _accPlsPerHeartBeat.add(
                tokenReward.mul(1e18).div(_totalHeartBeats)
            );
        }
        return
            stake.heartBeat.mul(_accPlsPerHeartBeat).div(1e18).sub(
                stake.rewardDebt
            );
    }

    function getUserStats(
        address _user
    )
        external
        view
        returns (
            uint256[] memory activeStakesIDs,
            uint256[] memory endedStakesIDs,
            uint256 claimed,
            uint256 staked,
            uint256 lastDepositTime,
            uint256 lastClaimTime,
            uint256 lastWithdrawTime,
            uint256 totalHeartBeat
        )
    {
        activeStakesIDs = users[_user].activeStakes.values();
        endedStakesIDs = users[_user].endedStakes.values();
        claimed = users[_user].claimed;
        staked = users[_user].staked;
        lastDepositTime = users[_user].lastDepositTime;
        lastClaimTime = users[_user].lastClaimTime;
        lastWithdrawTime = users[_user].lastWithdrawTime;
        totalHeartBeat = users[_user].totalHeartBeat;
    }

    function getUserActiveStakes(
        address _user
    ) external view returns (StakeView[] memory activeStakes) {
        EnumerableSet.UintSet storage activeStakesIDs = users[_user]
            .activeStakes;
        activeStakes = new StakeView[](activeStakesIDs.length());
        for (uint256 i = 0; i < activeStakesIDs.length(); i++) {
            uint256 stakeID = activeStakesIDs.at(i);
            StakeData memory stake = stakes[stakeID];
            activeStakes[i] = StakeView({
                id: stake.id,
                owner: stake.owner,
                stakeTime: stake.stakeTime,
                duration: stake.duration,
                stakeEndTime: stake.stakeEndTime,
                stakeWithdrawTime: stake.stakeWithdrawTime,
                amount: stake.amount,
                claimed: stake.claimed,
                heartBeat: stake.heartBeat,
                lastUpdate: stake.lastUpdate,
                lastClaim: stake.lastClaim,
                rewardDebt: stake.rewardDebt,
                pendingRewards: pendingPLS(stakeID)
            });
        }
    }
}
