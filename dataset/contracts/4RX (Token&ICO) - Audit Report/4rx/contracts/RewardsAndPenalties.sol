// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Pools.sol";


contract RewardsAndPenalties is Pools {
    using SafeMath for uint;

    function _distributeReferralReward(uint amount, Stake memory stake, address uplinkAddress, uint8 uplinkStakeId) internal {
        User storage uplinkUser = users[uplinkAddress];

        uint commission = _calcPercentage(amount, REF_COMMISSION_BP);

        uplinkUser.stakes[uplinkStakeId].rewards = uplinkUser.stakes[uplinkStakeId].rewards.add(commission);

        _updateRefPoolUsers(uplinkUser, stake, uplinkStakeId);
    }

    function _calcDepositRewards(uint amount) internal pure returns (uint) {
        uint rewardPercent = 0;

        if (amount > 175 * (10**fourRXTokenDecimals)) {
            rewardPercent = 50; // 0.5%
        } else if (amount > 150 * (10**fourRXTokenDecimals)) {
            rewardPercent = 40; // 0.4%
        } else if (amount > 135 * (10**fourRXTokenDecimals)) {
            rewardPercent = 35; // 0.35%
        } else if (amount > 119 * (10**fourRXTokenDecimals)) {
            rewardPercent = 30; // 0.3%
        } else if (amount > 100 * (10**fourRXTokenDecimals)) {
            rewardPercent = 25; // 0.25%
        } else if (amount > 89 * (10**fourRXTokenDecimals)) {
            rewardPercent = 20; // 0.2%
        } else if (amount > 75 * (10**fourRXTokenDecimals)) {
            rewardPercent = 15; // 0.15%
        } else if (amount > 59 * (10**fourRXTokenDecimals)) {
            rewardPercent = 10; // 0.1%
        } else if (amount > 45 * (10**fourRXTokenDecimals)) {
            rewardPercent = 5; // 0.05%
        } else if (amount > 20 * (10**fourRXTokenDecimals)) {
            rewardPercent = 2; // 0.02%
        } else if (amount > 9 * (10**fourRXTokenDecimals)) {
            rewardPercent = 1; // 0.01%
        }

        return _calcPercentage(amount, rewardPercent);
    }

    function _calcContractBonus(Stake memory stake) internal view returns (uint) {
        uint contractBonusPercent = fourRXToken.balanceOf(address(this)).mul(CONTRACT_BONUS_PER_UNIT_BP).div(CONTRACT_BONUS_UNIT).div(10**fourRXTokenDecimals);

        if (contractBonusPercent > MAX_CONTRACT_BONUS_BP) {
            contractBonusPercent = MAX_CONTRACT_BONUS_BP;
        }

        return _calcPercentage(stake.deposit, contractBonusPercent);
    }

    function _calcHoldRewards(Stake memory stake) internal view returns (uint) {
        uint holdBonusPercent = (block.timestamp).sub(stake.holdFrom).mul(HOLD_BONUS_PER_UNIT_BP).div(HOLD_BONUS_UNIT);

        if (holdBonusPercent > MAX_HOLD_BONUS_BP) {
            holdBonusPercent = MAX_HOLD_BONUS_BP;
        }

        return _calcPercentage(stake.deposit, holdBonusPercent);
    }

    function _calcRewardsWithoutHoldBonus(Stake memory stake) internal view returns (uint) {
        uint interest = _calcPercentage(stake.deposit, _getInterestTillDays(_calcDays(stake.interestCountFrom, block.timestamp)));

        uint contractBonus = _calcContractBonus(stake);

        uint totalRewardsWithoutHoldBonus = stake.rewards.add(interest).add(contractBonus);

        return totalRewardsWithoutHoldBonus;
    }

    function _calcRewards(Stake memory stake) internal view returns (uint) {
        uint rewards = _calcRewardsWithoutHoldBonus(stake);

        if (_calcBasisPoints(stake.deposit, rewards) >= REWARD_THRESHOLD_BP) {
            rewards = rewards.add(_calcHoldRewards(stake));
        }

        uint maxRewards = _calcPercentage(stake.deposit, MAX_CONTRACT_REWARD_BP);

        if (rewards > maxRewards) {
            rewards = maxRewards;
        }

        return rewards;
    }

    function _calcPenalty(Stake memory stake, uint withdrawalAmount) internal pure returns (uint) {
        uint basisPoints = _calcBasisPoints(stake.deposit, withdrawalAmount);
        // If user's rewards are more then REWARD_THRESHOLD_BP -- No penalty
        if (basisPoints >= REWARD_THRESHOLD_BP) {
            return 0;
        }

        return _calcPercentage(withdrawalAmount, PERCENT_MULTIPLIER.sub(basisPoints.mul(PERCENT_MULTIPLIER).div(REWARD_THRESHOLD_BP)));
    }
}
