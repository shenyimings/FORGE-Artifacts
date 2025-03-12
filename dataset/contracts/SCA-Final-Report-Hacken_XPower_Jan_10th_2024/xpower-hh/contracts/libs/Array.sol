// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

library Array {
    /** @return true if array is sorted */
    function sorted(uint256[] memory array) internal pure returns (bool) {
        for (uint256 i = 1; i < array.length; i++) {
            if (array[i - 1] <= array[i]) {
                continue;
            }
            return false;
        }
        return true;
    }

    /** @return true if array is sorted and free of duplicates */
    function unique(uint256[] memory array) internal pure returns (bool) {
        for (uint256 i = 1; i < array.length; i++) {
            if (array[i - 1] < array[i]) {
                continue;
            }
            return false;
        }
        return true;
    }
}
