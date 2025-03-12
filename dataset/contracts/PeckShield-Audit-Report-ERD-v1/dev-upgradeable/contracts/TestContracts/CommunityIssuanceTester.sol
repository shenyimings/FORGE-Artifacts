// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../CommunityIssuance.sol";

contract CommunityIssuanceTester is CommunityIssuance {
    function unprotectedIssue() external returns (uint256) {
        return 0;
    }
}
