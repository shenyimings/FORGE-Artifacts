// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/user-keeper/IGovUserKeeper.sol";

library GovPoolUnlock {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    function unlockInProposals(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        address user
    ) external {
        EnumerableSet.UintSet storage userProposals = userInfos[user].votedInProposals;
        uint256[] memory proposalIds = userProposals.values();

        (, address userKeeperAddress, , , ) = IGovPool(address(this)).getHelperContracts();
        IGovUserKeeper userKeeper = IGovUserKeeper(userKeeperAddress);

        uint256 maxLockedAmount = userKeeper.maxLockedAmount(user);
        uint256 maxUnlocked;

        for (uint256 i; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];

            if (_proposalIsActive(proposalId)) {
                continue;
            }

            IGovPool.RawVote storage personalRawVote = userInfos[user]
                .voteInfos[proposalId]
                .rawVotes[IGovPool.VoteType.PersonalVote];

            uint256 lockedInProposal = personalRawVote.tokensVoted;

            maxUnlocked = maxUnlocked.max(lockedInProposal);

            if (lockedInProposal != 0) {
                userKeeper.unlockTokens(proposalId, user);
            }

            if (personalRawVote.nftsVoted.length() != 0) {
                userKeeper.unlockNfts(personalRawVote.nftsVoted.values());
            }

            userProposals.remove(proposalId);
        }

        if (maxLockedAmount == maxUnlocked) {
            userKeeper.updateMaxTokenLockedAmount(userProposals.values(), user);
        }
    }

    function _proposalIsActive(uint256 proposalId) internal view returns (bool) {
        IGovPool.ProposalState state = IGovPool(address(this)).getProposalState(proposalId);

        return
            state != IGovPool.ProposalState.ExecutedFor &&
            state != IGovPool.ProposalState.ExecutedAgainst &&
            state != IGovPool.ProposalState.SucceededFor &&
            state != IGovPool.ProposalState.SucceededAgainst &&
            state != IGovPool.ProposalState.Defeated &&
            state != IGovPool.ProposalState.Locked;
    }
}
