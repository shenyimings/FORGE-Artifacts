// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

contract Stake is Ownable {
    using SafeMath for uint256;
    IERC20 public token;
    uint256 public rewardRate;
    struct StakerData {
        uint256 totalStaked;
        uint256 lastStakedTimestamp;
        uint256 reward;
        uint256 lastDayTimestamp;
    }
    struct rewardRateData {
        uint256 rewardRate;
        uint256 startTimestamp;
        uint256 endTimestamp;
    }
    rewardRateData[] private rewardRateHistory;
    address public commissionRecipient;
    mapping(address => StakerData) private stakers;
    constructor(IERC20 _token, uint256 _rewardRate) {
        rewardRate = _rewardRate;
        token = _token;
        rewardRateHistory.push(rewardRateData(_rewardRate, block.timestamp, type(uint256).max));
        commissionRecipient = msg.sender;
    }

    function calculateReward(address _user) internal view returns (uint256) {
        StakerData storage staker = stakers[_user];
        uint256 stakingDuration = block.timestamp.sub(staker.lastStakedTimestamp);
        uint256 _reward = getRewardRate(staker.lastStakedTimestamp);
        if (_reward == 0) {
            return 0;
        } else {
            return staker.totalStaked.mul(_reward).mul(stakingDuration).div(315360000000);
        }
    }

    function stake(uint256 amount, uint256 stakeDuration) public {
        require(amount > 0, "Amount must be greater than 0");
        require(stakeDuration >= 30, "Duration must be greater than or equal 30");
        token.transferFrom(msg.sender, address(this), amount);

        // Update staker's data
        StakerData storage staker = stakers[msg.sender];
        staker.reward = staker.reward.add(calculateReward(msg.sender));
        staker.totalStaked = staker.totalStaked.add(amount);
        staker.lastStakedTimestamp = block.timestamp;
        if (staker.lastDayTimestamp < block.timestamp.add(stakeDuration.mul(86400))) {
            staker.lastDayTimestamp = block.timestamp.add(stakeDuration.mul(86400));
        }
    }

    function unstake(uint256 amount) public {
        StakerData storage staker = stakers[msg.sender];
        require(staker.totalStaked >= amount && staker.totalStaked > 0, "Not enough staked tokens");
        staker.reward = staker.reward.add(calculateReward(msg.sender));
        staker.totalStaked = staker.totalStaked.sub(amount);
        staker.lastStakedTimestamp = block.timestamp;
        if (staker.lastDayTimestamp <= block.timestamp) {
            token.transfer(msg.sender, amount);
        } else {
            token.transfer(commissionRecipient, amount.mul(3).div(10));
            token.transfer(msg.sender, amount.mul(7).div(10));
        }
        if (staker.totalStaked == 0) {
            staker.lastDayTimestamp = 0;
        }
    }

    function claimReward() public {
        StakerData storage staker = stakers[msg.sender];
        uint256 reward = staker.reward.add(calculateReward(msg.sender));
        require(reward > 0, "No reward to claim");

        staker.reward = 0;
        staker.lastStakedTimestamp = block.timestamp;

        token.transfer(msg.sender, reward);
    }

    function unstakeAll() public {
        StakerData storage staker = stakers[msg.sender];
        uint256 reward = staker.reward.add(calculateReward(msg.sender));
        uint256 _amount = staker.totalStaked;

        require(_amount > 0 || reward > 0, "Not enough staked tokens");

        staker.reward = 0;
        staker.totalStaked = 0;
        staker.lastStakedTimestamp = block.timestamp;

        if (staker.lastDayTimestamp <= block.timestamp) {
            token.transfer(msg.sender, _amount.add(reward));
        } else {
            token.transfer(commissionRecipient, _amount.mul(3).div(10));
            token.transfer(msg.sender, _amount.mul(7).div(10).add(reward));
        }
        staker.lastDayTimestamp = 0;
    }

    function getReward() public view returns (uint256) {
        StakerData storage staker = stakers[msg.sender];
        uint256 reward = staker.reward.add(calculateReward(msg.sender));
        return reward;
    }

    function getRewardRate(uint256 _startTimestemp) internal view returns (uint256) {
        require(block.timestamp >= _startTimestemp, "timestemp error");
        if (_startTimestemp == 0 || _startTimestemp == block.timestamp) {
            return 0;
        }
        uint256 _i = binarySearch(_startTimestemp);
        uint256 _rate;
        uint256 _time = block.timestamp.sub(_startTimestemp);
        for (uint i = _i; i < rewardRateHistory.length; i++) {
            if (rewardRateHistory[i].endTimestamp < block.timestamp) {
                if (i == _i) {
                    _rate = _rate.add(rewardRateHistory[i].rewardRate.mul(rewardRateHistory[i].endTimestamp.sub(_startTimestemp)));
                } else {
                    _rate = _rate.add(rewardRateHistory[i].rewardRate.mul(rewardRateHistory[i].endTimestamp.sub(rewardRateHistory[i].startTimestamp)));
                }
            } else {
                _rate = _rate.add(rewardRateHistory[i].rewardRate.mul(block.timestamp.sub(rewardRateHistory[i].startTimestamp)));
            }
        }
        return _rate.div(_time);
    }

    function getStakers() public view returns (StakerData memory) {
        return stakers[msg.sender];
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        rewardRate = _rewardRate;
        rewardRateHistory[rewardRateHistory.length.sub(1)].endTimestamp = block.timestamp.sub(1);
        rewardRateHistory.push(rewardRateData(_rewardRate, block.timestamp, type(uint256).max));
    }

    function withdraw(address _tokenAddress, uint256 _amount) public onlyOwner {
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }

    function setComRecipient(address _commissionRecipient) public onlyOwner {
        commissionRecipient = _commissionRecipient;
    }

    function binarySearch(uint256 _startTimestemp) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = rewardRateHistory.length;
        while (low < high) {
            uint256 mid = (low & high) + (low ^ high) / 2;
            if (rewardRateHistory[mid].startTimestamp > _startTimestemp) {
                high = mid;
            } else if (rewardRateHistory[mid].startTimestamp <= _startTimestemp && rewardRateHistory[mid].endTimestamp >= _startTimestemp) {
                return mid;
            } else {
                low = mid.add(1);
            }
        }
        if (low > 0 && rewardRateHistory[low.sub(1)].startTimestamp <= _startTimestemp && rewardRateHistory[low.sub(1)].endTimestamp >= _startTimestemp) {
            return low.sub(1);
        } else {
            return low;
        }
    }
}