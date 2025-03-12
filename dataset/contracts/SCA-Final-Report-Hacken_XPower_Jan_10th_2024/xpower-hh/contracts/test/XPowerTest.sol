// SPDX-License-Identifier: GPL-3.0
// solhint-disable no-empty-blocks
// solhint-disable not-rely-on-time
// solhint-disable one-contract-per-file
pragma solidity ^0.8.20;

import {XPower} from "../XPower.sol";

/** Test class for XPower */
contract XPowerTest is XPower {
    constructor(address[] memory _base, uint256 _deadlineIn) XPower(_base, _deadlineIn) {}

    function fake(address to, uint256 amount) external {
        _mint(owner(), amount * 2);
        _mint(to, amount);
    }

    function hashOf(address to, bytes32 blockHash, bytes calldata data) external view returns (bytes32, bytes32) {
        return super._hashOf(to, blockHash, data);
    }

    function zerosOf(bytes32 nonceHash) external pure returns (uint8) {
        return super._zerosOf(nonceHash);
    }

    function amountOf(uint256 level) external view returns (uint256) {
        return super._amountOf(level);
    }
}

contract XPowerOldTest is XPowerTest {
    constructor(address[] memory _base, uint256 _deadlineIn) XPowerTest(_base, _deadlineIn) {}

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}

contract XPowerOldTest36 is XPowerTest {
    constructor(address[] memory _base, uint256 _deadlineIn) XPowerTest(_base, _deadlineIn) {}

    function decimals() public pure override returns (uint8) {
        return 36;
    }
}
