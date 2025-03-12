// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

import {OrigamiGovernanceToken} from "src/OrigamiGovernanceToken.sol";
import {IGovernor} from "src/interfaces/IGovernor.sol";

import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";

contract OrigamiGovernorProposalTest is GovernorDiamondHelper {
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);
    }

    function testCanSubmitProposal() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        vm.prank(voter2);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalCreated(
            62912883481399652201384617016484797517292059425633292282859862689999298978076,
            voter2,
            targets,
            values,
            signatures,
            calldatas,
            604801,
            1209601,
            "New proposal"
        );
        coreFacet.propose(targets, values, calldatas, "New proposal");
    }

    function testCannotSubmitProposalWithZeroTargets() public {
        targets = new address[](0);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        vm.prank(voter2);
        vm.expectRevert("Governor: empty proposal");
        coreFacet.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitProposalWithTargetsButZeroValues() public {
        targets = new address[](1);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        vm.prank(voter2);
        vm.expectRevert("Governor: invalid proposal length");
        coreFacet.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitProposalWithTargetsButZeroCalldatas() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](0);
        vm.prank(voter2);
        vm.expectRevert("Governor: invalid proposal length");
        coreFacet.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitSameProposalTwice() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        vm.startPrank(voter2);
        coreFacet.propose(targets, values, calldatas, "New proposal");
        vm.expectRevert("Governor: proposal already exists");
        coreFacet.propose(targets, values, calldatas, "New proposal");
    }

    function testProposalWithParamsTokenMustSupportIVotes() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        vm.prank(voter2);
        vm.expectRevert("Governor: proposal token must support IVotes");
        coreFacet.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            abi.encode(address(timelock), bytes4(keccak256("simpleWeight(uint256)")))
        );
    }

    function testProposalWithParamsTokenMustBeAProposalToken() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // deploy another gov token via proxy
        ProxyAdmin diffGovTokenAdmin = new ProxyAdmin();
        OrigamiGovernanceToken diffGovTokenImpl = new OrigamiGovernanceToken();
        TransparentUpgradeableProxy diffGovTokenProxy = new TransparentUpgradeableProxy(
            address(diffGovTokenImpl),
            address(diffGovTokenAdmin),
            ""
        );
        OrigamiGovernanceToken diffGovToken = OrigamiGovernanceToken(address(diffGovTokenProxy));
        diffGovToken.initialize(owner, "Deciduous Tree Fellowship", "DTF", 10000000000000000000000000000);

        vm.prank(voter2);
        vm.expectRevert("Governor: proposal token not allowed");
        coreFacet.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            abi.encode(address(diffGovToken), bytes4(keccak256("simpleWeight(uint256)")))
        );
    }
}

contract OrigamiGovernorProposalVoteTest is GovernorDiamondHelper {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event ProposalExecuted(uint256 proposalId);

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0x0);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanVoteOnProposalWithDefaultParams() public {
        vm.startPrank(voter);
        proposalId = coreFacet.propose(targets, values, calldatas, "Simple Voting Proposal");
        vm.warp(block.timestamp + 7 days + 1);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        // our voting weight is 1 here, since this vote uses the membership token
        emit VoteCast(voter, proposalId, AGAINST, 1, "");
        coreFacet.castVote(proposalId, AGAINST);
    }

    function testCanVoteOnProposalWithParams() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, FOR, 100000000, "I like it");
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it");
    }

    function testAddressWithoutMembershipTokenCanDelegateToMember() public {
        // self-delegate to get voting power
        vm.prank(nonMember);
        govToken.delegate(newVoter);

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(newVoter);

        // newVoter has the weight of nonMember's delegated tokens
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(newVoter, proposalId, AGAINST, 56250000, "I vote with their weight!");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I vote with their weight!");
    }

    function testRedelegatingDoesNotAffectCurrentProposals() public {
        // voter delegates voting power to voter2
        vm.prank(voter);
        govToken.delegate(voter2);

        // voter2 votes with delegated power
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter2);
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it");

        // voter Redelegates to self
        vm.warp(block.timestamp + 1);
        vm.prank(voter);
        govToken.delegate(voter);

        // voter attempts to vote with their own power
        vm.warp(block.timestamp + 1);
        vm.prank(voter);
        vm.expectRevert("Governor: only accounts with delegated voting power can vote");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I don't like it");
    }

    function testCanLimitVotingByWeight() public {
        // self-delegate to get voting power
        vm.prank(newVoter);
        govToken.delegate(newVoter);

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(newVoter);

        // newVoter has correctly self-delegated, but their weight is zero
        vm.expectRevert("Governor: only accounts with delegated voting power can vote");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I don't like it.");
    }

    function testCanLimitVotingToMembershipTokenHolders() public {
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(address(0x2a23));

        vm.expectRevert("OrigamiGovernor: only members may vote");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I don't like it.");
    }

    function testCanReviseVote() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, FOR, 100000000, "I like it");
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it");

        // our voting system allows us to change our vote at any time,
        // regardless of the value of hasVoted
        assertEq(coreFacet.hasVoted(proposalId, voter), true);

        vm.warp(block.timestamp + 1);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, AGAINST, 100000000, "I no longer like it");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I no longer like it");

        assertEq(coreFacet.hasVoted(proposalId, voter), true);
    }
}

contract OrigamiGovernorLifeCycleTest is GovernorDiamondHelper {
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0x0);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanTransitionProposalThroughToExecution() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.warp(block.timestamp + 7 days + 1);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // console2.log("PR", Strings.toHexString(uint256(timelock.PROPOSER_ROLE())), 32);

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 1 days);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalExecuted(proposalId);
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);

        // advance to the the next block
        vm.warp(block.timestamp + 1);

        // proposal is in the executed state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    function testCanTransitionProposalThroughToCancellation() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.warp(block.timestamp + 7 days + 1);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // grant the diamond the CANCELLER_ROLE
        vm.startPrank(deployer);
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(origamiGovernorDiamond));
        vm.stopPrank();

        vm.startPrank(admin);
        // grant the admin the CANCELLER_ROLE
        coreFacet.grantRole(coreFacet.CANCELLER_ROLE(), admin);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalCanceled(proposalId);
        timelockControlFacet.cancel(targets, values, calldatas, proposalHash);
        vm.stopPrank();

        // advance to the the next block
        vm.warp(block.timestamp + 1);

        // proposal is in the canceled state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function testCannotQueueIfProposalIsDefeated() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 0, "I Don't like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.warp(block.timestamp + 7 days + 1);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));

        vm.expectRevert("Governor: proposal not successful");
        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
    }

    function testProposalTokenMustBeAConfiguredToken() public {
        targets[0] = address(origamiGovernorDiamond);
        values[0] = uint256(0);
        calldatas[0] =
            abi.encodeWithSignature("enableProposalToken(address,bool)", address(origamiGovernorDiamond), true);

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("Update Proposal Token"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "Update Proposal Token", params);

        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.warp(block.timestamp + 7 days + 1);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 1 days);
        // the underlying transaction is reverted due to the proposal token not being a configured token
        vm.expectRevert("TimelockController: underlying transaction reverted");
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);
    }

    function testCountingStrategyMustBeKnown() public {
        targets[0] = address(origamiGovernorDiamond);
        values[0] = uint256(0);
        calldatas[0] = abi.encodeWithSignature("enableCountingStrategy(bytes4,bool)", 0x54fd4d50, true);

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("Update Counting Strategy"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "Update Counting Strategy", params);

        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.warp(block.timestamp + 7 days + 1);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 1 days);
        // the underlying transaction is reverted due to the counting strategy not being known
        vm.expectRevert("TimelockController: underlying transaction reverted");
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);
    }

    function testDisableProposalToken() public {
        targets[0] = address(origamiGovernorDiamond);
        values[0] = uint256(0);
        calldatas[0] = abi.encodeWithSignature("enableProposalToken(address,bool)", address(memToken), false);

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("Update Proposal Token"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "Update Proposal Token", params);

        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.warp(block.timestamp + 7 days + 1);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 1 days);
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);

        vm.warp(block.timestamp + 1);
        assertFalse(coreFacet.isProposalTokenEnabled(address(memToken)));
        assertTrue(coreFacet.isProposalTokenEnabled(address(govToken)));
    }

    function testDisableCountingStrategy() public {
        targets[0] = address(origamiGovernorDiamond);
        values[0] = uint256(0);
        bytes4 simpleWeightSelector = bytes4(keccak256("simpleWeight(uint256)"));
        calldatas[0] = abi.encodeWithSignature("enableCountingStrategy(bytes4,bool)", simpleWeightSelector, false);

        // use the gov token for vote weight
        params = abi.encode(address(govToken), simpleWeightSelector);
        proposalHash = keccak256(bytes("Update Counting Strategy"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "Update Counting Strategy", params);

        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.warp(block.timestamp + 7 days + 1);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 1 days);
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);

        vm.warp(block.timestamp + 1);
        // simple counting strategy is disabled
        assertFalse(coreFacet.isCountingStrategyEnabled(simpleWeightSelector));
        // quadratic counting strategy is still enabled
        assertTrue(coreFacet.isCountingStrategyEnabled(bytes4(keccak256("quadraticWeight(uint256)"))));
    }
}

contract OrigamiGovernorProposalQuorumTest is GovernorDiamondHelper {
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testUnreachedQuorumDefeatsProposal() public {
        // travel to proposal voting period completion
        vm.warp(block.timestamp + 14 days + 1);
        assertEq(coreFacet.quorum(proposalId), 84375000);
        // there have been no votes, so quorum will not be reached and state will be Defeated
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function testReachedQuorumButDefeated() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // travel to proposal voting period
        vm.warp(block.timestamp + 7 days + 1);

        // vote against the proposal - voter weight exceeds quorum
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I don't like it.");

        // travel to proposal voting period completion
        vm.warp(block.timestamp + 7 days + 1);

        // assert vote failed
        (uint256 againstVotes, uint256 forVotes,) = coreFacet.proposalVotes(proposalId);
        assertGt(againstVotes, forVotes);

        // quorum is reached, but the proposal is defeated
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function testReachedQuorumAndSucceeded() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // travel to proposal voting period
        vm.warp(block.timestamp + 7 days + 1);

        // vote against the proposal - voter weight exceeds quorum
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it.");

        // travel to proposal voting period completion
        vm.warp(block.timestamp + 7 days + 1);

        // assert vote failed
        (uint256 againstVotes, uint256 forVotes,) = coreFacet.proposalVotes(proposalId);
        assertGt(forVotes, againstVotes);

        // quorum is reached, but the proposal is defeated
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));
    }
}
