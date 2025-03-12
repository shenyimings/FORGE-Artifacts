// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/gov/IGovPool.sol";

library TypeHelper {
    function asSingletonArray(
        IGovPool.VoteType element
    ) internal pure returns (IGovPool.VoteType[] memory arr) {
        arr = new IGovPool.VoteType[](1);
        arr[0] = element;
    }

    function asDynamic(
        IGovPool.VoteType[2] memory elements
    ) internal pure returns (IGovPool.VoteType[] memory arr) {
        arr = new IGovPool.VoteType[](2);
        arr[0] = elements[0];
        arr[1] = elements[1];
    }

    function asDynamic(
        IGovPool.VoteType[3] memory elements
    ) internal pure returns (IGovPool.VoteType[] memory arr) {
        arr = new IGovPool.VoteType[](3);
        arr[0] = elements[0];
        arr[1] = elements[1];
        arr[2] = elements[2];
    }
}
