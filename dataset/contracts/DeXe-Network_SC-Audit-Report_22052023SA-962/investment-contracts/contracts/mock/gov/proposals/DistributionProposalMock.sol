// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/IGovPool.sol";

import "../../../gov/proposals/DistributionProposal.sol";

contract DistributionProposalMock is DistributionProposal {
    bool public revertReceive;

    function setGovPool(address govPool) external {
        govAddress = govPool;
    }

    function setRevertReceive(bool flag) external {
        revertReceive = flag;
    }

    function getTotalVotes(
        uint256,
        address,
        IGovPool.VoteType
    ) external pure returns (uint256, uint256, uint256, bool) {
        return (90, 10, 0, false);
    }

    receive() external payable {
        require(!revertReceive);
    }
}
