// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { TestERC20 } from "../../test/shared/TestERC20.sol";

function mintCollateral(address tokenAddr, address to, uint256 amount) {
    TestERC20 token = TestERC20(tokenAddr);
    token.mint();
    token.transfer(to, amount);
}
