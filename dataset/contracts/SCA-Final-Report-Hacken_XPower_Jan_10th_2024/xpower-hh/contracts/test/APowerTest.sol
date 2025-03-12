// SPDX-License-Identifier: GPL-3.0
// solhint-disable no-empty-blocks
// solhint-disable one-contract-per-file
pragma solidity ^0.8.20;

import {APower} from "../APower.sol";

contract APowerTest is APower {
    constructor(address moeLink, address[] memory sovBase, uint256 deadlineIn) APower(moeLink, sovBase, deadlineIn) {}
}

contract APowerOldTest is APowerTest {
    constructor(
        address moeLink,
        address[] memory sovBase,
        uint256 deadlineIn
    ) APowerTest(moeLink, sovBase, deadlineIn) {}

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}

contract APowerOldTest36 is APowerTest {
    constructor(
        address moeLink,
        address[] memory sovBase,
        uint256 deadlineIn
    ) APowerTest(moeLink, sovBase, deadlineIn) {}

    function decimals() public pure override returns (uint8) {
        return 36;
    }
}
