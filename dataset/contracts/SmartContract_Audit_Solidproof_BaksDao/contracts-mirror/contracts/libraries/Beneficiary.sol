// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library Beneficiary {
    function split(uint256 b) internal pure returns (address beneficiary, uint256 share) {
        share = b & type(uint96).max;
        beneficiary = address(uint160(b >> 96));
    }
}
