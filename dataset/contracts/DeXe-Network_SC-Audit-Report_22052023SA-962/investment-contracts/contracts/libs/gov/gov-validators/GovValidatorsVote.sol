// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/validators/IGovValidators.sol";

import "../../../gov/validators/GovValidators.sol";
import "../../../gov/validators/GovValidatorsToken.sol";

import "./GovValidatorsUtils.sol";

import "../../../core/Globals.sol";

library GovValidatorsVote {
    using GovValidatorsUtils for *;

    function vote(
        IGovValidators.ProposalCore storage core,
        mapping(bool => uint256) storage votedInProposal,
        uint256 amount,
        bool isVoteFor
    ) external {
        require(core.proposalExists(), "Validators: proposal does not exist");
        require(
            core.getProposalState() == IGovValidators.ProposalState.Voting,
            "Validators: not Voting state"
        );
        require(votedInProposal[!isVoteFor] == 0, "Validators: need cancel");

        GovValidatorsToken token = GovValidators(payable(address(this))).govValidatorsToken();

        uint256 balanceAt = token.balanceOfAt(msg.sender, core.snapshotId);
        uint256 totalVoted = votedInProposal[isVoteFor] + amount;

        require(balanceAt != 0, "Validators: caller is not the validator");
        require(totalVoted <= balanceAt, "Validators: excessive vote amount");

        votedInProposal[isVoteFor] = totalVoted;

        if (isVoteFor) {
            core.votesFor += amount;
        } else {
            core.votesAgainst += amount;
        }

        if (core.quorumReached()) {
            core.executeAfter += uint64(block.timestamp);
        }
    }

    function cancelVote(
        IGovValidators.ProposalCore storage core,
        mapping(bool => uint256) storage votedInProposal
    ) external {
        require(core.proposalExists(), "Validators: proposal does not exist");
        require(
            core.getProposalState() == IGovValidators.ProposalState.Voting,
            "Validators: not Voting state"
        );

        uint256 amount = votedInProposal[false];

        bool isVoteFor;

        if (amount == 0) {
            amount = votedInProposal[true];

            require(amount != 0, "Validators: didn't vote");

            isVoteFor = true;
        }

        delete votedInProposal[isVoteFor];

        if (isVoteFor) {
            core.votesFor -= amount;
        } else {
            core.votesAgainst -= amount;
        }
    }
}
