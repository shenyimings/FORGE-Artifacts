// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/arrays/ArrayHelper.sol";

import "./GovPoolRewards.sol";

import "../../utils/TokenBalance.sol";
import "../../math/MathHelper.sol";

import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/user-keeper/IGovUserKeeper.sol";

library GovPoolMicropool {
    using TokenBalance for address;
    using Math for uint256;
    using MathHelper for uint256;
    using ArrayHelper for uint256[];
    using GovPoolRewards for *;

    event DelegatorRewardsClaimed(
        uint256 proposalId,
        address delegator,
        address delegatee,
        address token,
        uint256 amount
    );

    function saveDelegationInfo(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        address delegatee
    ) external {
        (, address userKeeper, , , ) = IGovPool(address(this)).getHelperContracts();

        IGovPool.DelegatorInfo storage delegatorInfo = userInfos[delegatee].delegatorInfos[
            msg.sender
        ];

        uint256[] storage delegationTimes = delegatorInfo.delegationTimes;
        uint256[] storage delegationPowers = delegatorInfo.delegationPowers;

        uint256 length = delegationTimes.length;

        if (length > 0 && delegationTimes[length - 1] == block.timestamp) {
            delegationTimes.pop();
            delegationPowers.pop();
        }

        delegationTimes.push(block.timestamp);
        delegationPowers.push(
            IGovUserKeeper(userKeeper).getDelegatedAssetsPower(msg.sender, delegatee)
        );
    }

    function claim(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        uint256 proposalId,
        address delegator,
        address delegatee
    ) external {
        uint256 reward = _getExpectedRewards(
            userInfos,
            proposals,
            proposalId,
            delegator,
            delegatee
        );

        require(reward != 0, "Gov: no micropool rewards");

        IGovPool.DelegatorInfo storage delegatorInfo = userInfos[delegatee].delegatorInfos[
            delegator
        ];

        delegatorInfo.isClaimed[proposalId] = true;

        address rewardToken = proposals[proposalId].core.settings.rewardsInfo.rewardToken;

        uint256 paid = rewardToken.sendFunds(delegator, reward, TokenBalance.TransferType.TryMint);

        if (paid < reward) {
            delegatorInfo.isClaimed[proposalId] = false;
            delegatorInfo.partiallyClaimed[proposalId] += paid;
        }

        emit DelegatorRewardsClaimed(proposalId, delegator, delegatee, rewardToken, paid);
    }

    function getDelegatorRewards(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        uint256[] calldata proposalIds,
        address delegator,
        address delegatee
    ) external view returns (IGovPool.DelegatorRewards memory rewards) {
        rewards.expectedRewards = new uint256[](proposalIds.length);
        rewards.rewardTokens = new address[](proposalIds.length);
        rewards.isVoteFor = new bool[](proposalIds.length);
        rewards.isClaimed = new bool[](proposalIds.length);

        IGovPool.UserInfo storage userInfo = userInfos[delegatee];

        for (uint256 i; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];

            IGovPool.Proposal storage proposal = proposals[proposalId];

            if (!proposal.core.executed) {
                continue;
            }

            rewards.expectedRewards[i] = _getExpectedRewards(
                userInfos,
                proposals,
                proposalId,
                delegator,
                delegatee
            );
            rewards.rewardTokens[i] = proposal.core.settings.rewardsInfo.rewardToken;
            rewards.isVoteFor[i] = userInfo.voteInfos[proposalId].isVoteFor;
            rewards.isClaimed[i] = userInfo.delegatorInfos[delegator].isClaimed[proposalId];
        }
    }

    function _getExpectedRewards(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        uint256 proposalId,
        address delegator,
        address delegatee
    ) private view returns (uint256) {
        IGovPool.ProposalCore storage core = proposals[proposalId].core;
        IGovPool.UserInfo storage userInfo = userInfos[delegatee];
        IGovPool.RawVote storage micropoolRawVote = userInfo.voteInfos[proposalId].rawVotes[
            IGovPool.VoteType.MicropoolVote
        ];
        IGovPool.DelegatorInfo storage delegatorInfo = userInfo.delegatorInfos[delegator];

        (, uint256 delegatorsRewards) = core._getVotingRewards(userInfos, proposalId, delegatee);

        if (!core.executed || delegatorInfo.isClaimed[proposalId] || delegatorsRewards == 0) {
            return 0;
        }

        uint256[] storage timestamps = delegatorInfo.delegationTimes;

        uint256 quorumReachedTime = core.executeAfter - core.settings.executionDelay;
        uint256 index = timestamps.lowerBound(quorumReachedTime);

        if (index == 0) {
            return 0;
        }

        if (index == timestamps.length || timestamps[index] != quorumReachedTime) {
            --index;
        }

        uint256 totalVoted = micropoolRawVote.totalVoted;

        uint256 reward = delegatorsRewards.ratio(
            delegatorInfo.delegationPowers[index],
            totalVoted
        );

        return reward - delegatorInfo.partiallyClaimed[proposalId];
    }
}
