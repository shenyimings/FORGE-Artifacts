// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorCoreFacet} from "src/governor/GovernorCoreFacet.sol";
import {GovernorSettingsFacet} from "src/governor/GovernorSettingsFacet.sol";
import {GovernorTimelockControlFacet} from "src/governor/GovernorTimelockControlFacet.sol";

import {DiamondCutFacet} from "@diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "@diamond/facets/OwnershipFacet.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";

/**
 * @author Origami
 * @dev Common functions for the Governor modules.
 * @custom:security-contact contract-security@joinorigami.com
 */
library DiamondDeployHelper {
    function diamondLoupeFacetCut(address diamondLoupeFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory diamondLoupeCut)
    {
        bytes4[] memory diamondLoupeSelectors = new bytes4[](5);
        diamondLoupeSelectors[0] = DiamondLoupeFacet.facetAddress.selector;
        diamondLoupeSelectors[1] = DiamondLoupeFacet.facetAddresses.selector;
        diamondLoupeSelectors[2] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        diamondLoupeSelectors[3] = DiamondLoupeFacet.facets.selector;
        diamondLoupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;
        diamondLoupeCut = IDiamondCut.FacetCut({
            facetAddress: diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: diamondLoupeSelectors
        });
    }

    function ownershipFacetCut(address ownershipFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory ownershipCut)
    {
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipFacet.owner.selector;
        ownershipCut = IDiamondCut.FacetCut({
            facetAddress: ownershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });
    }

    function governorCoreFacetCut(GovernorCoreFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorCoreCut)
    {
        bytes4[] memory selectors = new bytes4[](35);
        selectors[0] = facet.CANCELLER_ROLE.selector;
        selectors[1] = facet.DEFAULT_ADMIN_ROLE.selector;
        selectors[2] = facet.EIP712_TYPEHASH.selector;
        selectors[3] = facet.IDEMPOTENT_BALLOT_TYPEHASH.selector;
        selectors[4] = facet.IDEMPOTENT_PROPOSAL_TYPEHASH.selector;
        selectors[5] = facet.castVote.selector;
        selectors[6] = facet.castVoteBySig.selector;
        selectors[7] = facet.castVoteWithReason.selector;
        selectors[8] = facet.castVoteWithReasonBySig.selector;
        selectors[9] = facet.domainSeparatorV4.selector;
        selectors[10] = facet.getAccountNonce.selector;
        selectors[11] = facet.getRoleAdmin.selector;
        selectors[12] = facet.getVotes.selector;
        selectors[13] = facet.grantRole.selector;
        selectors[14] = facet.hasRole.selector;
        selectors[15] = facet.hasVoted.selector;
        selectors[16] = facet.hashProposal.selector;
        selectors[17] = facet.isCountingStrategyEnabled.selector;
        selectors[18] = facet.isProposalTokenEnabled.selector;
        selectors[19] = facet.name.selector;
        selectors[20] = facet.proposalDeadline.selector;
        selectors[21] = facet.proposalSnapshot.selector;
        selectors[22] = facet.proposalVotes.selector;
        selectors[23] = facet.propose.selector;
        selectors[24] = facet.proposeBySig.selector;
        selectors[25] = facet.proposeWithParams.selector;
        selectors[26] = facet.proposeWithParamsBySig.selector;
        selectors[27] = facet.proposeWithTokenAndCountingStrategy.selector;
        selectors[28] = facet.proposeWithTokenAndCountingStrategyBySig.selector;
        selectors[29] = facet.quorum.selector;
        selectors[30] = facet.renounceRole.selector;
        selectors[31] = facet.revokeRole.selector;
        selectors[32] = facet.simpleWeight.selector;
        selectors[33] = facet.state.selector;
        selectors[34] = facet.version.selector;

        governorCoreCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function governorSettingsFacetCut(GovernorSettingsFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorSettingsCut)
    {
        bytes4[] memory selectors = new bytes4[](22);
        selectors[0] = facet.defaultCountingStrategy.selector;
        selectors[1] = facet.defaultProposalToken.selector;
        selectors[2] = facet.enableCountingStrategy.selector;
        selectors[3] = facet.enableProposalToken.selector;
        selectors[4] = facet.governanceToken.selector;
        selectors[5] = facet.membershipToken.selector;
        selectors[6] = facet.proposalThreshold.selector;
        selectors[7] = facet.proposalThresholdToken.selector;
        selectors[8] = facet.quorumDenominator.selector;
        selectors[9] = facet.quorumNumerator.selector;
        selectors[10] = facet.setDefaultCountingStrategy.selector;
        selectors[11] = facet.setDefaultProposalToken.selector;
        selectors[12] = facet.setGovernanceToken.selector;
        selectors[13] = facet.setMembershipToken.selector;
        selectors[14] = facet.setProposalThreshold.selector;
        selectors[15] = facet.setProposalThresholdToken.selector;
        selectors[16] = facet.setQuorumDenominator.selector;
        selectors[17] = facet.setQuorumNumerator.selector;
        selectors[18] = facet.setVotingDelay.selector;
        selectors[19] = facet.setVotingPeriod.selector;
        selectors[20] = facet.votingDelay.selector;
        selectors[21] = facet.votingPeriod.selector;

        governorSettingsCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function governorTimelockControlFacetCut(GovernorTimelockControlFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorTimelockControlCut)
    {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = facet.cancel.selector;
        selectors[1] = facet.execute.selector;
        selectors[2] = facet.proposalEta.selector;
        selectors[3] = facet.queue.selector;
        selectors[4] = facet.timelock.selector;
        selectors[5] = facet.updateTimelock.selector;

        governorTimelockControlCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
