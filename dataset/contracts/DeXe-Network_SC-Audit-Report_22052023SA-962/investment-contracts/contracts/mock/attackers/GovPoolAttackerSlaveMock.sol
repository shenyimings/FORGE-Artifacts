// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../interfaces/gov/IGovPool.sol";

contract GovPoolAttackerSlaveMock {
    function vote(IGovPool govPool, uint256 proposalId) external {
        govPool.vote(proposalId, true, 0, new uint256[](0));
    }
}
