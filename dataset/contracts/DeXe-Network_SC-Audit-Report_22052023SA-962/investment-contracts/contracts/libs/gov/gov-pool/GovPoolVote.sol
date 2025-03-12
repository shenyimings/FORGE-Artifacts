// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/utils/TypeCaster.sol";

import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/user-keeper/IGovUserKeeper.sol";
import "../../../interfaces/gov/voting/IVotePower.sol";

import "../../math/MathHelper.sol";

import "../../utils/TypeHelper.sol";

library GovPoolVote {
    using EnumerableSet for EnumerableSet.UintSet;
    using Math for uint256;
    using MathHelper for uint256;
    using TypeCaster for *;
    using TypeHelper for *;

    event VoteChanged(uint256 proposalId, address voter, bool isVoteFor, uint256 totalVoted);
    event QuorumReached(uint256 proposalId, uint256 timestamp);
    event QuorumUnreached(uint256 proposalId);

    function vote(
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        mapping(address => IGovPool.UserInfo) storage userInfos,
        uint256 proposalId,
        uint256 amount,
        uint256[] calldata nftIds,
        bool isVoteFor
    ) external {
        IGovPool.ProposalCore storage core = proposals[proposalId].core;
        IGovPool.UserInfo storage userInfo = userInfos[msg.sender];
        IGovPool.VoteInfo storage voteInfo = userInfo.voteInfos[proposalId];

        IGovPool.VoteType voteType = core.settings.delegatedVotingAllowed
            ? IGovPool.VoteType.DelegatedVote
            : IGovPool.VoteType.PersonalVote;

        _canVote(userInfos, proposalId, amount, voteType);

        mapping(IGovPool.VoteType => IGovPool.RawVote) storage rawVotes = voteInfo.rawVotes;

        if (amount != 0 || nftIds.length != 0) {
            (, address userKeeperAddress, , , ) = IGovPool(address(this)).getHelperContracts();
            IGovUserKeeper userKeeper = IGovUserKeeper(userKeeperAddress);

            if (amount != 0) {
                userKeeper.lockTokens(proposalId, msg.sender, amount);
            }

            if (nftIds.length != 0) {
                userKeeper.lockNfts(msg.sender, voteType, nftIds);
            }

            _vote(rawVotes[IGovPool.VoteType.PersonalVote], amount, nftIds, msg.sender, voteType);
        }

        if (voteType != IGovPool.VoteType.DelegatedVote) {
            _voteDelegated(
                userInfos,
                rawVotes[IGovPool.VoteType.MicropoolVote],
                proposalId,
                msg.sender,
                IGovPool.VoteType.MicropoolVote
            );

            _voteDelegated(
                userInfos,
                rawVotes[IGovPool.VoteType.TreasuryVote],
                proposalId,
                msg.sender,
                IGovPool.VoteType.TreasuryVote
            );
        }

        _updateGlobalState(core, userInfos, proposalId, msg.sender, isVoteFor);

        require(
            voteInfo.totalRawVoted >= core.settings.minVotesForVoting,
            "Gov: low voting power"
        );
    }

    function revoteDelegated(
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        mapping(address => IGovPool.UserInfo) storage userInfos,
        address voter,
        IGovPool.VoteType voteType
    ) external {
        IGovPool.UserInfo storage userInfo = userInfos[voter];

        uint256[] memory proposalIds = userInfo.votedInProposals.values();

        for (uint256 i = 0; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];

            if (!_isVotingState(proposalId)) {
                continue;
            }

            IGovPool.ProposalCore storage core = proposals[proposalId].core;
            IGovPool.VoteInfo storage voteInfo = userInfo.voteInfos[proposalId];
            IGovPool.RawVote storage rawVote = voteInfo.rawVotes[voteType];

            if (core.settings.delegatedVotingAllowed) {
                continue;
            }

            _cancel(rawVote);
            _voteDelegated(userInfos, rawVote, proposalId, voter, voteType);

            _updateGlobalState(core, userInfos, proposalId, voter, voteInfo.isVoteFor);
        }
    }

    function cancelVote(
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        mapping(address => IGovPool.UserInfo) storage userInfos,
        uint256 proposalId
    ) external {
        require(_isVotingState(proposalId), "Gov: cancel unavailable");

        IGovPool.ProposalCore storage core = proposals[proposalId].core;
        IGovPool.UserInfo storage userInfo = userInfos[msg.sender];
        IGovPool.VoteInfo storage voteInfo = userInfo.voteInfos[proposalId];

        mapping(IGovPool.VoteType => IGovPool.RawVote) storage rawVotes = voteInfo.rawVotes;
        IGovPool.RawVote storage personalRawVote = rawVotes[IGovPool.VoteType.PersonalVote];

        (, address userKeeperAddress, , , ) = IGovPool(address(this)).getHelperContracts();
        IGovUserKeeper userKeeper = IGovUserKeeper(userKeeperAddress);

        if (personalRawVote.tokensVoted != 0) {
            userKeeper.unlockTokens(proposalId, msg.sender);
        }

        if (personalRawVote.nftsVoted.length() != 0) {
            userKeeper.unlockNfts(personalRawVote.nftsVoted.values());
        }

        _cancel(rawVotes[IGovPool.VoteType.PersonalVote]);

        if (!core.settings.delegatedVotingAllowed) {
            _cancel(rawVotes[IGovPool.VoteType.MicropoolVote]);
            _cancel(rawVotes[IGovPool.VoteType.TreasuryVote]);
        }

        _updateGlobalState(core, userInfos, proposalId, msg.sender, voteInfo.isVoteFor);

        userKeeper.updateMaxTokenLockedAmount(userInfo.votedInProposals.values(), msg.sender);
    }

    function _voteDelegated(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        IGovPool.RawVote storage rawVote,
        uint256 proposalId,
        address voter,
        IGovPool.VoteType voteType
    ) internal {
        if (
            voteType == IGovPool.VoteType.TreasuryVote &&
            userInfos[voter].treasuryExemptProposals.contains(proposalId)
        ) {
            return;
        }

        (, address userKeeper, , , ) = IGovPool(address(this)).getHelperContracts();

        (uint256 amount, ) = IGovUserKeeper(userKeeper).tokenBalance(voter, voteType);

        _vote(rawVote, amount, new uint256[](0), voter, voteType);
    }

    function _vote(
        IGovPool.RawVote storage rawVote,
        uint256 amount,
        uint256[] memory nftIds,
        address voter,
        IGovPool.VoteType voteType
    ) internal {
        EnumerableSet.UintSet storage nftsVoted = rawVote.nftsVoted;

        for (uint256 i; i < nftIds.length; i++) {
            require(nftsVoted.add(nftIds[i]), "Gov: NFT already voted");
        }

        (, address userKeeperAddress, , , ) = IGovPool(address(this)).getHelperContracts();
        IGovUserKeeper userKeeper = IGovUserKeeper(userKeeperAddress);

        (uint256 nftsPower, ) = userKeeper.getTotalNftsPower(nftIds, voteType, voter, false);

        rawVote.tokensVoted = amount;
        rawVote.totalVoted = amount + nftsPower;

        if (
            voteType == IGovPool.VoteType.PersonalVote ||
            voteType == IGovPool.VoteType.DelegatedVote
        ) {
            rawVote.nftsAmount = nftIds.length;
        } else {
            (rawVote.nftsAmount, ) = userKeeper.nftBalance(voter, voteType);
        }
    }

    function _cancel(IGovPool.RawVote storage rawVote) internal {
        rawVote.tokensVoted = 0;
        rawVote.totalVoted = 0;
        rawVote.nftsAmount = 0;

        EnumerableSet.UintSet storage nftsVoted = rawVote.nftsVoted;

        while (nftsVoted.length() > 0) {
            nftsVoted.remove(nftsVoted.at(0));
        }
    }

    function _updateGlobalState(
        IGovPool.ProposalCore storage core,
        mapping(address => IGovPool.UserInfo) storage userInfos,
        uint256 proposalId,
        address voter,
        bool isVoteFor
    ) internal {
        IGovPool.UserInfo storage userInfo = userInfos[voter];

        IGovPool.VoteInfo storage voteInfo = userInfo.voteInfos[proposalId];
        EnumerableSet.UintSet storage activeVotes = userInfo.votedInProposals;

        if (_isVoted(voteInfo)) {
            _globalVote(
                core,
                voteInfo,
                activeVotes,
                userInfo.treasuryExemptProposals,
                proposalId,
                voter,
                isVoteFor
            );
        } else {
            _globalCancel(core, voteInfo, activeVotes, proposalId, isVoteFor);
        }

        if (_quorumReached(core)) {
            uint64 quorumTimestamp = core.settings.earlyCompletion
                ? uint64(block.timestamp)
                : core.voteEnd;

            core.executeAfter = core.settings.executionDelay + quorumTimestamp;

            emit QuorumReached(proposalId, uint256(quorumTimestamp));
        } else if (core.executeAfter != 0) {
            core.executeAfter = 0;

            emit QuorumUnreached(proposalId);
        }

        emit VoteChanged(proposalId, voter, isVoteFor, voteInfo.totalVoted);
    }

    function _globalVote(
        IGovPool.ProposalCore storage core,
        IGovPool.VoteInfo storage voteInfo,
        EnumerableSet.UintSet storage activeVotes,
        EnumerableSet.UintSet storage treasuryExemptProposals,
        uint256 proposalId,
        address voter,
        bool isVoteFor
    ) internal {
        activeVotes.add(proposalId);

        require(
            activeVotes.length() <= IGovPool(address(this)).coreProperties().getGovVotesLimit(),
            "Gov: vote limit reached"
        );

        mapping(IGovPool.VoteType => IGovPool.RawVote) storage rawVotes = voteInfo.rawVotes;

        uint256 totalRawVoted = rawVotes[IGovPool.VoteType.PersonalVote].totalVoted +
            rawVotes[IGovPool.VoteType.MicropoolVote].totalVoted +
            rawVotes[IGovPool.VoteType.TreasuryVote].totalVoted;
        uint256 totalVoted = _calculateVotes(
            treasuryExemptProposals,
            proposalId,
            voter,
            totalRawVoted
        );

        if (isVoteFor) {
            core.rawVotesFor = core.rawVotesFor - voteInfo.totalRawVoted + totalRawVoted;
            core.votesFor = core.votesFor - voteInfo.totalVoted + totalVoted;
        } else {
            core.rawVotesAgainst = core.rawVotesAgainst - voteInfo.totalRawVoted + totalRawVoted;
            core.votesAgainst = core.votesAgainst - voteInfo.totalVoted + totalVoted;
        }

        voteInfo.isVoteFor = isVoteFor;
        voteInfo.totalRawVoted = totalRawVoted;
        voteInfo.totalVoted = totalVoted;
    }

    function _globalCancel(
        IGovPool.ProposalCore storage core,
        IGovPool.VoteInfo storage voteInfo,
        EnumerableSet.UintSet storage activeVotes,
        uint256 proposalId,
        bool isVoteFor
    ) internal {
        require(activeVotes.remove(proposalId), "Gov: not active");

        if (isVoteFor) {
            core.rawVotesFor -= voteInfo.totalRawVoted;
            core.votesFor -= voteInfo.totalVoted;
        } else {
            core.rawVotesAgainst -= voteInfo.totalRawVoted;
            core.votesAgainst -= voteInfo.totalVoted;
        }

        voteInfo.isVoteFor = false;
        voteInfo.totalVoted = 0;
        voteInfo.totalRawVoted = 0;
    }

    function _canVote(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        uint256 proposalId,
        uint256 amount,
        IGovPool.VoteType voteType
    ) internal view {
        IGovPool govPool = IGovPool(address(this));

        (, address userKeeper, , , ) = govPool.getHelperContracts();
        (uint256 tokenBalance, uint256 ownedBalance) = IGovUserKeeper(userKeeper).tokenBalance(
            msg.sender,
            voteType
        );

        IGovPool.UserInfo storage userInfo = userInfos[msg.sender];

        require(_isVotingState(proposalId), "Gov: vote unavailable");
        require(!_isVoted(userInfo.voteInfos[proposalId]), "Gov: need cancel");
        require(amount <= tokenBalance - ownedBalance, "Gov: wrong vote amount");
    }

    function _isVoted(IGovPool.VoteInfo storage voteInfo) internal view returns (bool) {
        mapping(IGovPool.VoteType => IGovPool.RawVote) storage rawVotes = voteInfo.rawVotes;

        IGovPool.RawVote storage personalRawVote = rawVotes[IGovPool.VoteType.PersonalVote];
        IGovPool.RawVote storage micropoolRawVote = rawVotes[IGovPool.VoteType.MicropoolVote];
        IGovPool.RawVote storage treasuryRawVote = rawVotes[IGovPool.VoteType.TreasuryVote];

        /// @dev nft power can be zero
        return
            personalRawVote.totalVoted != 0 ||
            micropoolRawVote.totalVoted != 0 ||
            treasuryRawVote.totalVoted != 0 ||
            personalRawVote.nftsAmount != 0 ||
            micropoolRawVote.nftsAmount != 0 ||
            treasuryRawVote.nftsAmount != 0;
    }

    function _quorumReached(IGovPool.ProposalCore storage core) internal view returns (bool) {
        (, address userKeeperAddress, , , ) = IGovPool(address(this)).getHelperContracts();

        return
            PERCENTAGE_100.ratio(
                core.votesFor + core.votesAgainst,
                IGovUserKeeper(userKeeperAddress).getTotalPower()
            ) >= core.settings.quorum;
    }

    function _calculateVotes(
        EnumerableSet.UintSet storage treasuryExemptProposals,
        uint256 proposalId,
        address voter,
        uint256 voteAmount
    ) internal view returns (uint256) {
        (, address userKeeper, , , address votePower) = IGovPool(address(this))
            .getHelperContracts();

        IGovUserKeeper.VotingPowerView[] memory votingPowers = IGovUserKeeper(userKeeper)
            .votingPower(
                [voter, voter, voter].asDynamic(),
                [
                    IGovPool.VoteType.PersonalVote,
                    IGovPool.VoteType.MicropoolVote,
                    IGovPool.VoteType.TreasuryVote
                ].asDynamic(),
                false
            );

        return
            IVotePower(votePower).transformVotesFull(
                voter,
                voteAmount,
                votingPowers[0].rawPower,
                votingPowers[1].rawPower,
                treasuryExemptProposals.contains(proposalId) ? 0 : votingPowers[2].rawPower
            );
    }

    function _isVotingState(uint256 proposalId) internal view returns (bool) {
        return
            IGovPool(address(this)).getProposalState(proposalId) == IGovPool.ProposalState.Voting;
    }
}
