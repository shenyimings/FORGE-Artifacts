// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BEP20Harness.sol";

contract VBEP20Harness is BEP20Harness {
    /**
     * @notice Underlying asset for this VToken
     */
    address public underlying;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals,
        address underlying_
    ) BEP20Harness(name_, symbol_, decimals) {
        underlying = underlying_;
    }
}
