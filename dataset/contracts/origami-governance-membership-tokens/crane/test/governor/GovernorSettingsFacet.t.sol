// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {IGovernor} from "src/interfaces/IGovernor.sol";
import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

contract SettingsFacetTest is GovernorDiamondHelper {
    function testInformationalFunctions() public {
        assertEq(settingsFacet.votingDelay(), 604_800);
        assertEq(settingsFacet.votingPeriod(), 604_800);
        assertEq(settingsFacet.proposalThreshold(), 1);
    }

    function testRetrieveDefaultCountingStrategy() public {
        assertEq(settingsFacet.defaultCountingStrategy(), bytes4(keccak256("simpleWeight(uint256)")));
    }

    function testRetrieveDefaultProposalToken() public {
        assertEq(settingsFacet.defaultProposalToken(), address(memToken));
    }

    function testRetrieveGovernanceToken() public {
        assertEq(settingsFacet.governanceToken(), address(govToken));
    }

    function testRetrieveMembershipToken() public {
        assertEq(settingsFacet.membershipToken(), address(memToken));
    }

    function testRetrieveProposalThreshold() public {
        assertEq(settingsFacet.proposalThreshold(), 1);
    }

    function testRetrieveProposalThresholdToken() public {
        assertEq(settingsFacet.proposalThresholdToken(), address(memToken));
    }

    function testRetrieveQuorumNumerator() public {
        assertEq(settingsFacet.quorumNumerator(), 10);
    }

    function testRetrieveQuorumDenominator() public {
        assertEq(settingsFacet.quorumDenominator(), 100);
    }

    function testRetrieveVotingDelay() public {
        assertEq(settingsFacet.votingDelay(), 604_800);
    }

    function testRetrieveVotingPeriod() public {
        assertEq(settingsFacet.votingPeriod(), 604_800);
    }

    function testCannotDirectlyUpdateDefaultCountingStrategy() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setDefaultCountingStrategy(bytes4(0));
    }

    function testCannotDirectlyUpdateDefaultProposalToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setDefaultProposalToken(address(0));
    }

    function testCannotDirectlyUpdateGovernanceToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setGovernanceToken(address(0));
    }

    function testCannotDirectlyUpdateMembershipToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setMembershipToken(address(0));
    }

    function testCannotDirectlyUpdateProposalThreshold() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setProposalThreshold(0);
    }

    function testCannotDirectlyUpdateProposalThresholdToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setProposalThresholdToken(address(0));
    }

    function testCannotDirectlyUpdateQuorumNumerator() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setQuorumNumerator(0);
    }

    function testCannotDirectlyUpdateQuorumDenominator() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setQuorumDenominator(0);
    }

    function testCannotDirectlyUpdateVotingDelay() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setVotingDelay(0);
    }

    function testCannotDirectlyUpdateVotingPeriod() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setVotingPeriod(0);
    }

    function testTimelockCanUpdateDefaultCountingStrategy() public {
        vm.prank(address(timelock));
        settingsFacet.setDefaultCountingStrategy(bytes4(0));
    }

    function testTimelockCanUpdateDefaultProposalToken() public {
        vm.prank(address(timelock));
        settingsFacet.setDefaultProposalToken(address(0xbeef));
    }

    function testTimelockCanUpdateGovernanceToken() public {
        vm.prank(address(timelock));
        settingsFacet.setGovernanceToken(address(0xbeef));
    }

    function testTimelockCanUpdateMembershipToken() public {
        vm.prank(address(timelock));
        settingsFacet.setMembershipToken(address(0xbeef));
    }

    function testTimelockCanUpdateProposalThreshold() public {
        vm.prank(address(timelock));
        settingsFacet.setProposalThreshold(0);
    }

    function testTimelockCanUpdateProposalThresholdToken() public {
        vm.prank(address(timelock));
        settingsFacet.setProposalThresholdToken(address(0xbeef));
    }

    function testTimelockCanUpdateQuorumNumerator() public {
        vm.prank(address(timelock));
        settingsFacet.setQuorumNumerator(0);
    }

    function testTimelockCanUpdateQuorumDenominator() public {
        vm.prank(address(timelock));
        settingsFacet.setQuorumDenominator(0);
    }

    function testTimelockCanUpdateVotingDelay() public {
        vm.prank(address(timelock));
        settingsFacet.setVotingDelay(0);
    }

    function testTimelockCanUpdateVotingPeriod() public {
        vm.prank(address(timelock));
        settingsFacet.setVotingPeriod(0);
    }

    function testMembershipTokenEnabled() public {
        assertEq(coreFacet.isProposalTokenEnabled(address(memToken)), true);
    }

    function testGovernanceTokenEnabled() public {
        assertEq(coreFacet.isProposalTokenEnabled(address(govToken)), true);
    }

    function testSimpleCountingStrategyEnabled() public {
        assertEq(coreFacet.isCountingStrategyEnabled(bytes4(keccak256("simpleWeight(uint256)"))), true);
    }

    function testQuadraticCountingStrategyEnabled() public {
        assertEq(coreFacet.isCountingStrategyEnabled(bytes4(keccak256("quadraticWeight(uint256)"))), true);
    }
}

contract OrigamiGovernorUpdateSettingsViaProposal is GovernorDiamondHelper {
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;
    address public newGovToken;

    function setUp() public {
        newGovToken = address(0xBadBeef);
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(origamiGovernorDiamond);
        values[0] = uint256(0);
        calldatas[0] = abi.encodeWithSignature("setGovernanceToken(address)", newGovToken);

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testUpdateGovernanceTokenViaProposal() public {
        // check that the governance token has been updated
        assertEq(settingsFacet.governanceToken(), address(govToken));

        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // advance to the voting period
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.warp(block.timestamp + 7 days);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // wait a day, then execute the proposal
        vm.warp(block.timestamp + 1 days);
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);

        // advance past the execution delay
        vm.roll(604_843 + 604_801);

        // proposal is in the executed state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Executed));

        // check that the governance token has been updated
        assertEq(settingsFacet.governanceToken(), newGovToken);
    }
}
