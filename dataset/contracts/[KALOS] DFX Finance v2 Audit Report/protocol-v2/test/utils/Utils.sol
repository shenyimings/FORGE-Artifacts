// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract Utils {
    function tenToPowerOf(uint256 decimals) public pure returns (uint256 pow){
        if (decimals == 2) {
            return 1e2;
        } else if (decimals == 8) {
            return 1e8;
        }
         else if (decimals == 6) {
            return 1e6;
        } else if (decimals == 18) {
            return 1e18;
        } else if(decimals == 0) {
            return 1;
        } else return 0;
    }
}
