// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../interfaces/core/ICoreProperties.sol";

import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/ERC721/multipliers/IAbstractERC721Multiplier.sol";

import "../../utils/TokenBalance.sol";
import "../../math/MathHelper.sol";

library GovPoolRewards {
    using EnumerableSet for EnumerableSet.AddressSet;
    using TokenBalance for address;
    using MathHelper for uint256;
    using Math for uint256;

    event RewardClaimed(uint256 proposalId, address sender, address token, uint256 rewards);
    event VotingRewardClaimed(
        uint256 proposalId,
        address sender,
        address token,
        IGovPool.VotingRewards rewards
    );

    function updateStaticRewards(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        uint256 proposalId,
        address user,
        IGovPool.RewardType rewardType
    ) external {
        IGovPool.ProposalCore storage core = proposals[proposalId].core;
        IGovSettings.RewardsInfo storage rewardsInfo = core.settings.rewardsInfo;

        uint256 amountToAdd = rewardType == IGovPool.RewardType.Create
            ? rewardsInfo.creationReward
            : rewardsInfo.executionReward;

        userInfos[user].pendingRewards.staticRewards[proposalId] += amountToAdd;

        core.givenRewards += amountToAdd;
    }

    function updateOffchainRewards(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        address user
    ) external {
        (address govSettings, , , , ) = IGovPool(address(this)).getHelperContracts();

        IGovSettings.RewardsInfo memory rewardsInfo = IGovSettings(govSettings)
            .getInternalSettings()
            .rewardsInfo;

        address rewardToken = rewardsInfo.rewardToken;

        IGovPool.PendingRewards storage userRewards = userInfos[user].pendingRewards;

        userRewards.offchainRewards[rewardToken] += rewardsInfo.executionReward;
        userRewards.offchainTokens.add(rewardToken);
    }

    function updateVotingRewards(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        uint256 proposalId,
        address user
    ) external {
        IGovPool.ProposalCore storage core = proposals[proposalId].core;
        IGovPool.PendingRewards storage userRewards = userInfos[user].pendingRewards;

        if (userRewards.areVotingRewardsSet[proposalId]) {
            return;
        }

        (IGovPool.VotingRewards memory votingRewards, ) = _getVotingRewards(
            core,
            userInfos,
            proposalId,
            user
        );

        if (votingRewards.personal + votingRewards.micropool + votingRewards.treasury == 0) {
            return;
        }

        userRewards.votingRewards[proposalId] = votingRewards;
        userRewards.areVotingRewardsSet[proposalId] = true;
    }

    function claimReward(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        uint256 proposalId,
        address user
    ) external {
        IGovPool.PendingRewards storage userRewards = userInfos[user].pendingRewards;

        if (proposalId != 0) {
            IGovPool.ProposalCore storage core = proposals[proposalId].core;

            require(core.executed, "Gov: proposal is not executed");

            uint256 staticRewardsToPay = userRewards.staticRewards[proposalId];
            uint256 staticRewardsPaid;

            IGovPool.VotingRewards memory votingRewardsToPay = userRewards.votingRewards[
                proposalId
            ];
            IGovPool.VotingRewards memory votingRewardsPaid;

            delete userRewards.staticRewards[proposalId];
            delete userRewards.votingRewards[proposalId];

            address rewardToken = core.settings.rewardsInfo.rewardToken;

            uint256 rewardsPaid = _sendRewards(
                user,
                core.settings.rewardsInfo.rewardToken,
                staticRewardsToPay +
                    votingRewardsToPay.personal +
                    votingRewardsToPay.micropool +
                    votingRewardsToPay.treasury
            );

            (staticRewardsToPay, staticRewardsPaid) = _recalculateAllRewards(
                rewardsPaid,
                staticRewardsToPay,
                votingRewardsPaid,
                votingRewardsToPay
            );

            userRewards.staticRewards[proposalId] = staticRewardsToPay;
            userRewards.votingRewards[proposalId] = votingRewardsToPay;

            emit RewardClaimed(proposalId, user, rewardToken, staticRewardsPaid);
            emit VotingRewardClaimed(proposalId, user, rewardToken, votingRewardsPaid);
        } else {
            EnumerableSet.AddressSet storage offchainTokens = userRewards.offchainTokens;
            mapping(address => uint256) storage offchainRewards = userRewards.offchainRewards;

            uint256 length = offchainTokens.length();

            for (uint256 i = length; i > 0; i--) {
                address rewardToken = offchainTokens.at(i - 1);
                uint256 rewards = offchainRewards[rewardToken];

                delete offchainRewards[rewardToken];

                uint256 paid = _sendRewards(user, rewardToken, rewards);

                if (paid < rewards) {
                    offchainRewards[rewardToken] = rewards - paid;
                } else {
                    offchainTokens.remove(rewardToken);
                }

                emit RewardClaimed(0, user, rewardToken, paid);
            }
        }
    }

    function getPendingRewards(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        address user,
        uint256[] calldata proposalIds
    ) external view returns (IGovPool.PendingRewardsView memory rewards) {
        IGovPool.PendingRewards storage userRewards = userInfos[user].pendingRewards;

        uint256 tokensLength = userRewards.offchainTokens.length();

        rewards.onchainTokens = new address[](proposalIds.length);
        rewards.staticRewards = new uint256[](proposalIds.length);
        rewards.votingRewards = new IGovPool.VotingRewards[](proposalIds.length);
        rewards.offchainRewards = new uint256[](tokensLength);
        rewards.offchainTokens = new address[](tokensLength);

        for (uint256 i = 0; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];

            IGovPool.ProposalCore storage core = proposals[proposalId].core;

            if (!core.executed) {
                continue;
            }

            rewards.onchainTokens[i] = core.settings.rewardsInfo.rewardToken;
            rewards.staticRewards[i] = userRewards.staticRewards[proposalId];

            if (!userRewards.areVotingRewardsSet[proposalId]) {
                (rewards.votingRewards[i], ) = _getVotingRewards(
                    core,
                    userInfos,
                    proposalId,
                    user
                );
            } else {
                rewards.votingRewards[i] = userRewards.votingRewards[proposalId];
            }
        }

        for (uint256 i = 0; i < rewards.offchainTokens.length; i++) {
            address token = userRewards.offchainTokens.at(i);

            rewards.offchainTokens[i] = token;
            rewards.offchainRewards[i] = userRewards.offchainRewards[token];
        }
    }

    function _sendRewards(
        address receiver,
        address rewardToken,
        uint256 rewards
    ) internal returns (uint256) {
        require(rewardToken != address(0), "Gov: rewards are off");
        require(rewards != 0, "Gov: zero rewards");

        return rewardToken.sendFunds(receiver, rewards, TokenBalance.TransferType.TryMint);
    }

    function _getMultipliedRewards(address user, uint256 amount) internal view returns (uint256) {
        (address nftMultiplier, , , ) = IGovPool(address(this)).getNftContracts();

        if (nftMultiplier != address(0)) {
            amount += IAbstractERC721Multiplier(nftMultiplier).getExtraRewards(user, amount);
        }

        return amount;
    }

    function _getVotingRewards(
        IGovPool.ProposalCore storage core,
        mapping(address => IGovPool.UserInfo) storage userInfos,
        uint256 proposalId,
        address user
    )
        internal
        view
        returns (IGovPool.VotingRewards memory votingRewards, uint256 delegatorsRewards)
    {
        IGovPool.VoteInfo storage voteInfo = userInfos[user].voteInfos[proposalId];

        IGovPool.ProposalState executedState = voteInfo.isVoteFor
            ? IGovPool.ProposalState.ExecutedFor
            : IGovPool.ProposalState.ExecutedAgainst;

        if (
            IGovPool(address(this)).getProposalState(proposalId) != executedState ||
            voteInfo.totalRawVoted == 0
        ) {
            return (votingRewards, 0);
        }

        return _splitVotingRewards(voteInfo, user, _getInitialVotingRewards(core, voteInfo));
    }

    function _getInitialVotingRewards(
        IGovPool.ProposalCore storage core,
        IGovPool.VoteInfo storage voteInfo
    ) internal view returns (uint256) {
        (uint256 coreVotes, uint256 coreRawVotes) = voteInfo.isVoteFor
            ? (core.votesFor, core.rawVotesFor)
            : (core.votesAgainst, core.rawVotesAgainst);

        return
            coreRawVotes.ratio(core.settings.rewardsInfo.voteRewardsCoefficient, PRECISION).ratio(
                voteInfo.totalVoted,
                coreVotes
            );
    }

    function _splitVotingRewards(
        IGovPool.VoteInfo storage voteInfo,
        address user,
        uint256 totalRewards
    )
        internal
        view
        returns (IGovPool.VotingRewards memory votingRewards, uint256 delegatorsRewards)
    {
        mapping(IGovPool.VoteType => IGovPool.RawVote) storage rawVotes = voteInfo.rawVotes;

        uint256 personalRewards = rawVotes[IGovPool.VoteType.PersonalVote].totalVoted;
        uint256 micropoolRewards = rawVotes[IGovPool.VoteType.MicropoolVote].totalVoted;
        uint256 treasuryRewards = rawVotes[IGovPool.VoteType.TreasuryVote].totalVoted;
        uint256 totalRawVoted = voteInfo.totalRawVoted;

        (uint256 micropoolPercentage, uint256 treasuryPercentage) = ICoreProperties(
            IGovPool(address(this)).coreProperties()
        ).getVoteRewardsPercentages();

        votingRewards.personal = _getMultipliedRewards(
            user,
            totalRewards.ratio(personalRewards, totalRawVoted)
        );
        votingRewards.micropool = totalRewards.ratio(micropoolRewards, totalRawVoted);
        votingRewards.treasury = totalRewards.ratio(treasuryRewards, totalRawVoted).percentage(
            treasuryPercentage
        );

        delegatorsRewards = votingRewards.micropool.percentage(
            PERCENTAGE_100 - micropoolPercentage
        );

        votingRewards.micropool -= delegatorsRewards;
    }

    function _recalculateReward(
        uint256 rewardsPaid,
        uint256 rewardsToPay
    ) private pure returns (uint256, uint256, uint256) {
        uint256 amountMin = rewardsPaid.min(rewardsToPay);

        return (rewardsPaid - amountMin, amountMin, rewardsToPay - amountMin);
    }

    function _recalculateAllRewards(
        uint256 rewardsPaid,
        uint256 staticRewardsToPay,
        IGovPool.VotingRewards memory votingRewardsPaid,
        IGovPool.VotingRewards memory votingRewardsToPay
    ) private pure returns (uint256, uint256) {
        uint256 staticRewardsPaid;

        (rewardsPaid, staticRewardsPaid, staticRewardsToPay) = _recalculateReward(
            rewardsPaid,
            staticRewardsToPay
        );

        (
            rewardsPaid,
            votingRewardsPaid.personal,
            votingRewardsToPay.personal
        ) = _recalculateReward(rewardsPaid, votingRewardsToPay.personal);
        (
            rewardsPaid,
            votingRewardsPaid.micropool,
            votingRewardsToPay.micropool
        ) = _recalculateReward(rewardsPaid, votingRewardsToPay.micropool);
        (
            rewardsPaid,
            votingRewardsPaid.treasury,
            votingRewardsToPay.treasury
        ) = _recalculateReward(rewardsPaid, votingRewardsToPay.treasury);

        return (staticRewardsToPay, staticRewardsPaid);
    }
}
