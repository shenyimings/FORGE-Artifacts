// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../Indu40.sol";

/**
 * @title indu4.0 Mock ERC-20 Smart Contract
 */
contract Indu40Mock is Indu40 {
    constructor(address multisig_, uint256 amount_, uint256 cap_) Indu40(multisig_, amount_, cap_) {}

    function transferInternal(
        address from,
        address to,
        uint256 value
    ) public {
        _transfer(from, to, value);
    }

    function approveInternal(
        address owner,
        address spender,
        uint256 value
    ) public {
        _approve(owner, spender, value);
    }

    function getChainId() external view returns (uint256) {
        return block.chainid;
    }
}
