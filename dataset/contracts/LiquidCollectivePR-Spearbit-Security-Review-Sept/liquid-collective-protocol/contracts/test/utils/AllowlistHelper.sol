//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

library AllowlistHelper {
    function batchAllowees(uint256 length, uint256 right) public pure returns (uint256[] memory) {
        uint256[] memory statuses = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            statuses[i] = right;
        }
        return statuses;
    }
}
