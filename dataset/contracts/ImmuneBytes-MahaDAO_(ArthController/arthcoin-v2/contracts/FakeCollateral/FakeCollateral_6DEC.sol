// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './FakeCollateral.sol';

contract FakeCollateral_6DEC is FakeCollateral {
    constructor(
        address creator_address,
        uint256 genesis_supply,
        string memory symbol,
        uint8 decimals
    ) FakeCollateral(creator_address, genesis_supply, symbol, decimals) {}
}
