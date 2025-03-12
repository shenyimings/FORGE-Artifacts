// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/settings/IGovSettings.sol";
import "../../../interfaces/gov/validators/IGovValidators.sol";

import "../../utils/DataHelper.sol";
import "../../math/MathHelper.sol";
import "../../utils/TokenBalance.sol";
import "./GovPoolCommission.sol";

import "../../../gov/GovPool.sol";

library GovPoolExecute {
    using DataHelper for bytes;
    using MathHelper for uint256;
    using Math for uint256;
    using TokenBalance for address;
    using GovPoolCommission for address;

    event ProposalExecuted(uint256 proposalId, bool isFor, address sender);

    function execute(
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        uint256 proposalId
    ) external {
        IGovPool.Proposal storage proposal = proposals[proposalId];
        IGovPool.ProposalCore storage core = proposal.core;

        GovPool govPool = GovPool(payable(address(this)));

        IGovPool.ProposalState proposalState = govPool.getProposalState(proposalId);

        require(
            proposalState == IGovPool.ProposalState.SucceededFor ||
                proposalState == IGovPool.ProposalState.SucceededAgainst,
            "Gov: invalid status"
        );

        core.executed = true;

        (, , address govValidatorsAddress, , ) = GovPool(payable(address(this)))
            .getHelperContracts();
        IGovValidators govValidators = IGovValidators(govValidatorsAddress);

        bool validatorsVotingSucceeded = govValidators.getProposalState(proposalId, false) ==
            IGovValidators.ProposalState.Succeeded;

        if (validatorsVotingSucceeded) {
            govValidators.executeExternalProposal(proposalId);
        }

        IGovPool.ProposalAction[] storage actions = _proposalActionsResult(proposal);

        uint256 actionsLength = actions.length;

        for (uint256 i; i < actionsLength; i++) {
            (bool status, bytes memory returnedData) = actions[i].executor.call{
                value: actions[i].value
            }(actions[i].data);

            if (!status) {
                revert(returnedData.getRevertMsg());
            }
        }

        emit ProposalExecuted(
            proposalId,
            proposalState == IGovPool.ProposalState.SucceededFor,
            msg.sender
        );

        core.settings.rewardsInfo.rewardToken.payCommission(_getCommission(core));
    }

    function _proposalActionsResult(
        IGovPool.Proposal storage proposal
    ) internal view returns (IGovPool.ProposalAction[] storage) {
        IGovPool.ProposalCore storage core = proposal.core;

        return
            core.votesFor > core.votesAgainst ? proposal.actionsOnFor : proposal.actionsOnAgainst;
    }

    function _getCommission(IGovPool.ProposalCore storage core) internal view returns (uint256) {
        return
            core.givenRewards +
            (core.rawVotesFor + core.rawVotesAgainst).ratio(
                core.settings.rewardsInfo.voteRewardsCoefficient,
                PRECISION
            );
    }
}
