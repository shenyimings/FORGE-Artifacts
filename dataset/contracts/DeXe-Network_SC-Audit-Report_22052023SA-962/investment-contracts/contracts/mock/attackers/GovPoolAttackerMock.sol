// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/gov/IGovPool.sol";
import "./GovPoolAttackerSlaveMock.sol";

contract GovPoolAttackerMock {
    function attackDelegateUndelegate(
        IGovPool govPool,
        IERC20 votingToken,
        uint256 proposalId
    ) external {
        uint256 votingPower = votingToken.balanceOf(address(this));
        require(votingPower > 0, "AttackContract: need to send tokens first");

        GovPoolAttackerSlaveMock slave = new GovPoolAttackerSlaveMock();

        (, address userKeeperAddress, , , ) = govPool.getHelperContracts();
        votingToken.approve(userKeeperAddress, votingPower);

        govPool.deposit(votingPower, new uint256[](0));

        require(
            votingToken.balanceOf(address(this)) == 0,
            "AttackContract: balance should be 0 after depositing tokens"
        );

        govPool.delegate(address(slave), votingPower, new uint256[](0));

        slave.vote(govPool, proposalId);

        require(
            govPool.getProposalState(proposalId) == IGovPool.ProposalState.Locked,
            "AttackContract: proposal didn't move to Locked state after vote"
        );

        govPool.undelegate(address(slave), votingPower, new uint256[](0));
        govPool.withdraw(address(this), votingPower, new uint256[](0));

        require(
            votingToken.balanceOf(address(this)) == votingPower,
            "AttackContract: balance should be full after withdrawing"
        );

        require(
            govPool.getProposalState(proposalId) == IGovPool.ProposalState.Locked,
            "AttackContract: proposal should still be in Locked state after withdrawing tokens"
        );
    }
}
