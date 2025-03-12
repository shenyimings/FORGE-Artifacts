// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/validators/IGovValidators.sol";

import "../../../gov/validators/GovValidators.sol";
import "../../../gov/validators/GovValidatorsToken.sol";

import "../../math/MathHelper.sol";

import "../../../core/Globals.sol";

library GovValidatorsUtils {
    using MathHelper for uint256;

    function getProposalState(
        IGovValidators.ProposalCore storage core
    ) internal view returns (IGovValidators.ProposalState) {
        if (core.executed) {
            return IGovValidators.ProposalState.Executed;
        }

        if (quorumReached(core)) {
            if (_votesForMoreThanAgainst(core)) {
                if (block.timestamp <= core.executeAfter) {
                    return IGovValidators.ProposalState.Locked;
                }

                return IGovValidators.ProposalState.Succeeded;
            }

            return IGovValidators.ProposalState.Defeated;
        }

        if (core.voteEnd < block.timestamp) {
            return IGovValidators.ProposalState.Defeated;
        }

        return IGovValidators.ProposalState.Voting;
    }

    function quorumReached(IGovValidators.ProposalCore storage core) internal view returns (bool) {
        GovValidatorsToken token = GovValidators(payable(address(this))).govValidatorsToken();

        uint256 totalSupply = token.totalSupplyAt(core.snapshotId);
        uint256 currentQuorum = PERCENTAGE_100.ratio(
            core.votesFor + core.votesAgainst,
            totalSupply
        );

        return currentQuorum >= core.quorum;
    }

    function proposalExists(
        IGovValidators.ProposalCore storage core
    ) internal view returns (bool) {
        return core.voteEnd != 0;
    }

    function validateProposalSettings(
        IGovValidators.ProposalSettings memory proposalSettings
    ) internal pure {
        require(proposalSettings.duration > 0, "Validators: duration is zero");
        require(proposalSettings.quorum <= PERCENTAGE_100, "Validators: invalid quorum value");
        require(proposalSettings.quorum > 0, "Validators: invalid quorum value");
    }

    function validateChangeBalances(
        address[] memory userAddresses,
        uint256[] memory newValues
    ) internal pure {
        require(newValues.length == userAddresses.length, "Validators: invalid array length");

        for (uint256 i = 0; i < userAddresses.length; i++) {
            require(userAddresses[i] != address(0), "Validators: invalid address");
        }
    }

    function _votesForMoreThanAgainst(
        IGovValidators.ProposalCore storage core
    ) private view returns (bool) {
        return core.votesFor > core.votesAgainst;
    }
}
