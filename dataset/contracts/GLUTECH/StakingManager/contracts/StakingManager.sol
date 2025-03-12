//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract StakingManager is ReentrancyGuard {
    struct StakingPlan {
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 dailyROI;
        uint256 stakingPeriod;
        uint256 totalStaked;
        uint256 totalPayouts;
    }

    struct Staking {
        uint256 rewardDebt;
        uint256 totalInvestments;
        uint256 amount;
        uint256 initialTime;
        uint256 earningStartTime;
        uint256 totalWithdrawal;
        uint256 lockEndTime;
    }

    struct User {
        uint256 referralDebt;
        uint256 teamSalesDebt;
        uint256 lastTeamHarvest;
        uint256 totalInvestments;
        address referrer;
        mapping(uint256 => Staking) stakings;
        uint256 currentRank;
        uint256 totalDirectReferrals;
        uint256 totalCommissionEarned;
        address[] referrals;
        uint256 totalTeam;
        uint256 leadershipScore;
    }

    struct LeadershipRank {
        uint256 weeklyEarnings;
        uint256 directReferrals;
        uint256 teamVolume;
        uint256 investments;
    }

    address payable public immutable admin;
    address payable public immutable liquiditySupportBot;

    uint16 private constant HARVEST_FEE_PERCENTAGE = 300; // in percentage
    uint16 private constant PENALTY_PERCENTAGE = 2500; // in percentage
    uint16 private constant REFERRAL_LEVELS = 10;
    uint16 public constant LIQUIDITY_SUPPORT_PERCENTAGE = 2000; // 30%

    mapping(uint256 => LeadershipRank) public leadershipRanks;
    mapping(uint256 => StakingPlan) public stakingPlans;
    mapping(uint256 => uint256) public referralLevels;
    mapping(address => uint256) public referralCounts;
    mapping(address => address) private referrals;
    mapping(address => User) public users;

    uint256 public immutable contractInitializedAt;
    uint256 public totalTeams = 0;

    event Staked(address indexed staker, uint256 amount);
    event ReleaseBotSupport(uint256 amount);
    event Unstaked(address indexed staker, uint256 amount);
    event Harvested(address indexed staker, uint256 amount);
    event ReferralRecorded(address indexed user, address indexed referrer);
    event ReferralEarningsReceived(address indexed user, uint256 amount);
    event PenaltyCharged(address indexed offender, uint256 amount);

    modifier validPlanId(uint256 planId) {
        require(planId >= 1 && planId <= 3, "Invalid plan ID");
        _;
    }

    constructor(
        address payable adminAdd,
        address payable liquiditySupportBotAddress
    ) {
        require(
            adminAdd != address(0) && liquiditySupportBotAddress != address(0)
        );
        admin = adminAdd;
        liquiditySupportBot = liquiditySupportBotAddress;
        contractInitializedAt = block.timestamp;

        // Initialize referral levels
        referralLevels[1] = 1000;
        referralLevels[2] = 700;
        referralLevels[3] = 500;
        referralLevels[4] = 300;
        referralLevels[5] = 200;
        referralLevels[6] = 200;
        referralLevels[7] = 200;
        referralLevels[8] = 50;
        referralLevels[9] = 50;
        referralLevels[10] = 50;

        leadershipRanks[1] = LeadershipRank(
            0.18 ether,
            5,
            18.01 ether,
            0.36 ether
        );
        leadershipRanks[2] = LeadershipRank(
            0.36 ether,
            7,
            36 ether,
            0.36 ether
        );
        leadershipRanks[3] = LeadershipRank(
            0.90 ether,
            10,
            72.05 ether,
            1.80 ether
        );
        leadershipRanks[4] = LeadershipRank(
            1.8 ether,
            20,
            180.14 ether,
            3.60 ether
        );
        leadershipRanks[5] = LeadershipRank(
            7.21 ether,
            20,
            360.27 ether,
            10.7959 ether
        );
        leadershipRanks[6] = LeadershipRank(
            18.01 ether,
            20,
            900.69 ether,
            18 ether
        );
        leadershipRanks[7] = LeadershipRank(
            36.03 ether,
            20,
            3602.74 ether,
            36 ether
        );

        // Initialize staking plans
        stakingPlans[1] = StakingPlan(
            0.033 ether,
            1663.22 ether,
            200,
            7 days,
            0,
            0
        );
        stakingPlans[2] = StakingPlan(
            0.033 ether,
            1663.22 ether,
            250,
            30 days,
            0,
            0
        );
        stakingPlans[3] = StakingPlan(
            0.033 ether,
            1663.22 ether,
            300,
            60 days,
            0,
            0
        );
    }

    function teamEarnings(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];

        if (user.currentRank == 0 || user.lastTeamHarvest == 0) {
            return 0;
        }

        LeadershipRank memory leadershipRank = leadershipRanks[
            user.currentRank
        ];
        uint256 weeklyEarnings = leadershipRank.weeklyEarnings;

        uint256 lastHarvestWeek = user.lastTeamHarvest / 1 weeks;
        uint256 currentWeek = block.timestamp / 1 weeks;
        uint256 elapsedWeeks = currentWeek - lastHarvestWeek;

        if (elapsedWeeks == 0) {
            return 0;
        }

        uint256 pendingReward = elapsedWeeks * weeklyEarnings;

        return pendingReward;
    }

    function getRewards(
        address userAddress,
        uint256 planId
    ) public view validPlanId(planId) returns (uint256) {
        Staking storage staking = users[userAddress].stakings[planId];

        if (staking.amount == 0) {
            return staking.rewardDebt;
        }

        StakingPlan storage stakingPlan = stakingPlans[planId];
        uint256 timeDiff = block.timestamp - staking.earningStartTime;
        uint256 earningRate = staking.amount * stakingPlan.dailyROI;
        uint256 rewardAmount = (earningRate * Math.min(timeDiff, stakingPlan.stakingPeriod)) / (10000 * 1 days);

        return staking.rewardDebt + rewardAmount;
    }

    function getUserPlanDetails(
        address userAddress,
        uint256 planId
    ) external view returns (Staking memory, uint256) {
        uint256 reward = getRewards(userAddress, planId);
        Staking memory staking = users[userAddress].stakings[planId];
        return (staking, reward);
    }

    function getAllUserPlansEarnings(
        address userAddress
    ) public view returns (uint256) {
        uint256 planOneReward = getRewards(userAddress, 1);
        uint256 planTwoReward = getRewards(userAddress, 2);
        uint256 planThreeReward = getRewards(userAddress, 3);

        return planOneReward + planTwoReward + planThreeReward;
    }

    function getUserDetails(
        address userAddress
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 reward = getAllUserPlansEarnings(userAddress);
        User storage user = users[userAddress];
        return (
            user.referralDebt,
            user.teamSalesDebt,
            user.lastTeamHarvest,
            user.totalInvestments,
            user.referrer,
            user.currentRank,
            user.totalDirectReferrals,
            user.totalCommissionEarned,
            user.totalTeam,
            user.leadershipScore,
            reward
        );
    }

    function getAvailableReferralRewards(
        address userAddress
    ) public view returns (uint256) {
        User storage user = users[userAddress];
        return user.referralDebt;
    }

    function getReferralRewards(
        address userAddress
    ) public view returns (uint256) {
        uint256 pendingReward = 0;
        User storage user = users[userAddress];
        for (uint256 i = 0; i < user.referrals.length; i++) {
            uint256 userRewards = getAllUserPlansEarnings(user.referrals[i]);
            uint256 rewardsPercentage = referralLevels[1];
            pendingReward = pendingReward +
                ((userRewards * rewardsPercentage) / 10000);

            User storage referredUser = users[user.referrals[i]];
            uint256 generation = 1;
            uint256 maxGenerations = REFERRAL_LEVELS - 1;

            while (
                generation <= maxGenerations &&
                referredUser.referrals.length > 0
            ) {
                uint256 _referralsCount = referredUser.referrals.length;
                for (uint256 j = 0; j < _referralsCount; j++) {
                    address referrer = referredUser.referrals[j];
                    if (referrer == address(0)) continue;

                    userRewards = getAllUserPlansEarnings(referrer);
                    uint256 referralEarningsPercentage = referralLevels[
                        generation + 1
                    ];

                    uint256 referralEarningsShare = (
                        userRewards * referralEarningsPercentage
                    ) / 10000;
                    pendingReward = pendingReward + referralEarningsShare;
                }

                referredUser = users[referredUser.referrals[0]];
                generation++;
            }
        }

        return pendingReward;
    }

    function stake(
        uint256 planId
    ) external payable nonReentrant validPlanId(planId) {
        require(
            msg.value >= stakingPlans[planId].minStakeAmount &&
                msg.value <= stakingPlans[planId].maxStakeAmount,
            "Invalid staking amount"
        );

        require(users[msg.sender].referrer != address(0), "You must be referred to participate");

        updateUplinesEarnings(msg.sender, planId);
        updateUserStake(msg.sender, planId);

        User storage user = users[msg.sender];
        user.totalInvestments = user.totalInvestments + msg.value;

        StakingPlan storage stakingPlan = stakingPlans[planId];

        Staking storage staking = users[msg.sender].stakings[planId];
        staking.amount += msg.value;
        staking.initialTime = block.timestamp;
        staking.earningStartTime = block.timestamp;
        staking.lockEndTime = block.timestamp + stakingPlan.stakingPeriod;
        staking.totalInvestments = staking.totalInvestments + msg.value;

        stakingPlan.totalStaked += msg.value;

        updateLeadershipRank(msg.sender);
        balanceLeadershipRank(msg.sender, msg.value);

        emit Staked(msg.sender, msg.value);

        uint256 liquiditySupportFee = (
            msg.value * LIQUIDITY_SUPPORT_PERCENTAGE
        ) / 10000;

        emit ReleaseBotSupport(liquiditySupportFee);

        liquiditySupportBot.transfer(liquiditySupportFee);
    }

    function harvest(uint256 planId) external nonReentrant validPlanId(planId) {
        User storage user = users[msg.sender];
        Staking storage staking = users[msg.sender].stakings[planId];
        StakingPlan storage stakingPlan = stakingPlans[planId];

        uint256 teamSalesEarnings = user.teamSalesDebt + teamEarnings(msg.sender);
        uint256 rewardAmount = getRewards(msg.sender, planId) + teamSalesEarnings;
        require(rewardAmount > 0, "harvest: not enough funds");

        updateUplinesEarnings(msg.sender, planId);

        staking.rewardDebt = 0;
        staking.totalWithdrawal = staking.totalWithdrawal + rewardAmount;
        staking.earningStartTime = block.timestamp;

        user.teamSalesDebt = 0;
        user.lastTeamHarvest = block.timestamp;

        uint256 harvestFee = (rewardAmount * HARVEST_FEE_PERCENTAGE) / 10000;

        stakingPlan.totalPayouts += rewardAmount;

        emit Harvested(msg.sender, rewardAmount - harvestFee);

        payable(msg.sender).transfer(rewardAmount - harvestFee);
        admin.transfer(harvestFee);
    }

    function harvestReferralEarnings() external nonReentrant {
        User storage user = users[msg.sender];
        require(user.referralDebt > 0, "harvest: not enough funds");

        uint256 rewardAmount = user.referralDebt;

        user.referralDebt = 0;

        uint256 harvestFee = (rewardAmount * HARVEST_FEE_PERCENTAGE) / 10000;

        emit Harvested(msg.sender, rewardAmount - harvestFee);

        payable(msg.sender).transfer(rewardAmount - harvestFee);
        admin.transfer(harvestFee);
    }

    function unstake(uint256 planId) external nonReentrant validPlanId(planId) {
        User storage user = users[msg.sender];
        Staking storage staking = users[msg.sender].stakings[planId];
        StakingPlan storage stakingPlan = stakingPlans[planId];

        uint256 teamSalesEarnings = user.teamSalesDebt + teamEarnings(msg.sender);

        uint256 totalBalance = getRewards(msg.sender, planId) + staking.amount + teamSalesEarnings;
        require(totalBalance > 0, "Unstake: nothing to unstake");

        uint256 harvestFee = (totalBalance * HARVEST_FEE_PERCENTAGE) / 10000;
        uint256 harvestableAmount = _harvestableAmount(
            totalBalance,
            harvestFee,
            msg.sender,
            planId
        );

        require(
            address(this).balance >= totalBalance,
            "Insufficient fund to initiate unstake"
        );

        updateUplinesEarnings(msg.sender, planId);
        updateUserStake(msg.sender, planId);

        staking.amount = 0;
        staking.rewardDebt = 0;
        staking.totalWithdrawal = staking.totalWithdrawal + totalBalance;
        staking.earningStartTime = 0;

        user.teamSalesDebt = 0;
        user.lastTeamHarvest = block.timestamp;

        stakingPlan.totalPayouts += totalBalance;

        emit Unstaked(msg.sender, harvestableAmount);

        payable(msg.sender).transfer(harvestableAmount);
        admin.transfer(harvestFee);
    }

    function recordReferral(address referrerAddress) public nonReentrant {
        require(msg.sender.code.length == 0, "Contracts not allowed.");

        // Check for circular referral
        address currentReferrer = referrerAddress;
        while (currentReferrer != address(0)) {
            require(
                currentReferrer != msg.sender,
                "Circular referral detected."
            );
            currentReferrer = referrals[currentReferrer];
        }

        if (referrerAddress != address(0) && referrals[msg.sender] == address(0)) {
            User storage user = users[referrerAddress];
            User storage referredUser = users[msg.sender];

            referrals[msg.sender] = referrerAddress;
            referralCounts[referrerAddress]++;

            referredUser.referrer = referrerAddress;

            user.referrals.push(msg.sender);
            user.totalDirectReferrals = user.totalDirectReferrals + 1;

            totalTeams = totalTeams + 1;

            updateUplines(msg.sender);

            emit ReferralRecorded(msg.sender, referrerAddress);
        }
    }

    function _harvestableAmount(
        uint256 _amount,
        uint256 _harvestFee,
        address userAddress,
        uint256 planId
    ) private view returns (uint256) {
        Staking storage staking = users[userAddress].stakings[planId];
        uint256 harvestableAmount = _amount - _harvestFee;

        if (staking.lockEndTime > block.timestamp) {
            uint256 penalty = (harvestableAmount * PENALTY_PERCENTAGE) / 10000;
            harvestableAmount = harvestableAmount - penalty;
        }

        return harvestableAmount;
    }

    function updateUserStake(address userAddress, uint256 planId) internal {
        Staking storage staking = users[userAddress].stakings[planId];
        StakingPlan storage stakingPlan = stakingPlans[planId];

        uint256 rewardAmount = getRewards(userAddress, planId);
        staking.rewardDebt = rewardAmount;
        staking.initialTime = block.timestamp;
        staking.lockEndTime = staking.initialTime + stakingPlan.stakingPeriod;
    }

    function updateUplinesEarnings(address userAddress, uint256 planId) internal {
        if (referrals[userAddress] != address(0)) {
            uint256 userEarnings = getRewards(userAddress, planId);
            address[] memory userUps = getUplines(userAddress);

            for (uint i = 0; i < userUps.length; i++) {
                if (userUps[i] == address(0)) {
                    break;
                }
                User storage user = users[userUps[i]];
                uint256 referralEarningsPercentage = referralLevels[i + 1];
                uint256 referralReward = userEarnings * referralEarningsPercentage / 10000;
                user.referralDebt = user.referralDebt + referralReward;
                user.totalCommissionEarned += referralReward;
                emit ReferralEarningsReceived(userUps[i], referralReward);
            }
        }
    }

    function updateUplines(address userAddress) internal {
        address[] memory userUplines = getUplines(userAddress);

        for (uint256 i = 0; i < userUplines.length; i++) {
            address referrer = userUplines[i];

            if (referrer == address(0)) {
                break;
            }
            updateLeadershipRank(referrer);
            User storage user = users[referrer];
            user.totalTeam = user.totalTeam + 1;
        }
    }

    function getUplines(
        address userAddress
    ) internal view returns (address[] memory) {
        uint16 limit = 10;
        address[] memory uplines = new address[](limit);
        address current = userAddress;
        for (uint i = 0; i < limit; i++) {
            if (referrals[current] == address(0)) {
                break;
            }
            uplines[i] = referrals[current];
            current = uplines[i];
        }
        return uplines;
    }

    function balanceLeadershipRank(
        address userAddress,
        uint256 transactionAmount
    ) internal {
        address referrer = referrals[userAddress];
        if (referrer != address(0)) {
            address[] memory userUps = getUplines(userAddress);

            for (uint256 i = 0; i < userUps.length; i++) {
                if (userUps[i] == address(0)) {
                    break;
                }
                User storage user = users[userUps[i]];
                user.leadershipScore = user.leadershipScore + transactionAmount;
                updateLeadershipRank(userUps[i]);
            }
        }
    }

    function updateLeadershipRank(address uplineAddress) internal {
        uint256 totalLeadershipRanks = 7;
        User storage user = users[uplineAddress];
        uint256 currentPosition = user.currentRank;
        if (currentPosition != totalLeadershipRanks) {
            for (
                uint256 index = currentPosition;
                index < totalLeadershipRanks;
                index++
            ) {
                LeadershipRank memory leadershipRank = leadershipRanks[
                    index + 1
                ];
                if (
                    user.leadershipScore >= leadershipRank.teamVolume &&
                    user.totalInvestments >= leadershipRank.investments &&
                    user.totalDirectReferrals >= leadershipRank.directReferrals
                ) {
                    currentPosition = currentPosition + 1;
                }
            }
            if (currentPosition != user.currentRank) {
                user.teamSalesDebt += teamEarnings(uplineAddress);
                user.lastTeamHarvest = block.timestamp;
            }
            user.currentRank = currentPosition;
        }
    }
}
