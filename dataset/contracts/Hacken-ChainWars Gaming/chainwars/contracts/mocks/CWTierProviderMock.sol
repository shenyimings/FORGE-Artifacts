// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "../interfaces/ICWTierProvider.sol";
import "../abstracts/ERC20Votes.sol";

contract CWTierProviderMock is ICWTierProvider {
    function getTier(address a, uint256 votes) override public pure returns (uint8) {
        if (votes > 162e3 ether) {
            return 6;
        }
        if (votes > 54e3 ether) {
            return 5;
        }
        if (votes > 18e3 ether) {
            return 4;
        }
        if (votes > 6e3 ether) {
            return 3;
        }
        if (votes > 2e3 ether) {
            return 2;
        }
        if (votes >= 1 ether) {
            return 1;
        }

        return 0;
    }
}
