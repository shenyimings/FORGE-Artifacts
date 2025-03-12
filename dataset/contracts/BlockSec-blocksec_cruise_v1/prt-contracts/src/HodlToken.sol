// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { YToken } from "./YToken.sol";

contract HodlToken is YToken {
    constructor(address vault_,
                string memory name_,
                string memory symbol_) YToken(vault_, name_, symbol_) {}

    function trigger() external override onlyOwner {
        cumulativeYieldAcc = vault.cumulativeYield();
    }

    function isAccumulating() public override view returns (bool) {
        return vault.didTrigger();
    }
}
