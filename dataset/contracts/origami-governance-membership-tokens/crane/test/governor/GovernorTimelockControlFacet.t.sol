// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

contract TimelockControlFacetTest is GovernorDiamondHelper {
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    bytes32 public descriptionHash;
    string public description;
    uint256 public proposalId;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        description = "Update the governance token.";
        descriptionHash = keccak256(bytes(description));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithTokenAndCountingStrategy(
            targets, values, calldatas, description, address(govToken), bytes4(keccak256("simpleWeight(uint256)"))
        );
        vm.roll(block.number + 1);
    }

    function testRetrieveTimelock() public {
        assertEq(address(timelockControlFacet.timelock()), address(timelock));
    }

    function testRetrieveProposalEta() public {
        // for new proposals that have not been queued, eta is 0
        assertEq(timelockControlFacet.proposalEta(proposalId), 0);

        // wait til active, then vote in support to exceed the quorum
        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(voter2);
        coreFacet.castVote(proposalId, 1);
        vm.prank(voter3);
        coreFacet.castVote(proposalId, 1);
        vm.prank(voter4);
        coreFacet.castVote(proposalId, 1);

        // travel to the future and queue the proposal

        vm.warp(block.timestamp + 7 days);

        timelockControlFacet.queue(targets, values, calldatas, descriptionHash);
        assertEq(timelockControlFacet.proposalEta(proposalId), block.timestamp + 1 days);
    }

    function testCannotDirectlyUpdateTimelock() public {
        vm.expectRevert("Governor: onlyGovernance");
        timelockControlFacet.updateTimelock(payable(address(0)));
    }

    function testTimelockCanUpdateTimelock() public {
        vm.prank(address(timelock));
        timelockControlFacet.updateTimelock(payable(address(0)));
        assertEq(address(timelockControlFacet.timelock()), address(0));
    }
}
