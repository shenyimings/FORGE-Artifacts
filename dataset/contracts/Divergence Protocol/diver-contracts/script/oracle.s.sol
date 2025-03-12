// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { BaseScript } from "./shared/Base.s.sol";
import { OracleForTest as Oracle } from "../test/oracle/OracleForTest.sol";
import { TestERC20 } from "../test/shared/TestERC20.sol";

contract OracleSet is BaseScript {
    function setUp() public virtual override {
        super.setUp();
    }

    function run() public broadcaster {
        // mintToken();
        setPriceForTest();
    }

    function setPriceForTest() public {
        Oracle oracle = Oracle(address(0x1947457d02Fafa47E39371b99E87951Fb3fb932c));
        oracle.setPrice("BTC", 1682668800, 29495e18);
    }

    function mintToken() public {
        TestERC20 token = TestERC20(address(0xA87B4e604aCefd6Cf6059bb73a7b4e0bA90434DA));
        token.mint();
        token.transfer(address(0x22Ca9b22095DE647C28debC4dEa2Cb252Dfd531A), 100000e18);
    }
}
