// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../JetStakingV1.sol";

contract JetStakingTesting is JetStakingV1 {
    function before(uint256 startTime, uint256 endTime)
        public
        view
        returns (
            uint256 total,
            uint256 rewardPerShareAurora,
            uint256 scheduleCalculated
        )
    {
        total = rewardsSchedule(0, startTime, endTime);
        scheduleCalculated =
            rewardsSchedule(0, startTime, endTime) /
            1000000000000000000;
        if (totalAuroraShares != 0) {
            rewardPerShareAurora = total / (totalAuroraShares);
        } else {
            rewardPerShareAurora = total;
        }
    }

    function updateUserCalculation() external {
        _before();
    }

    function getTotalUserReward() external view returns (uint256 totalReward) {
        totalReward =
            users[msg.sender].auroraShares *
            (totalAmountOfStakedAurora / totalAuroraShares);
    }

    function calculateReward(address account) public view returns (uint256) {
        uint256 userShares = users[account].auroraShares;
        return (totalAmountOfStakedAurora * userShares) / totalAuroraShares;
    }

    function calculateWeightedShares(uint256 shares, uint256 timestamp)
        public
        view
        returns (uint256)
    {
        return _weightedShares(shares, timestamp);
    }
}
