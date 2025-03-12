// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../gov/proposals/TokenSaleProposal.sol";

contract TokenSaleProposalMock is TokenSaleProposal {
    function setGovPool(address govPool) external {
        govAddress = govPool;
    }
}
