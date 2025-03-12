// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Vester_BaseTest} from "./Vester_BaseTest.t.sol";
import {Vester} from "../../vesting/Vester.sol";

import {MockErc20} from "../mocks/MockERC20.sol";

import {Math} from "../../utils/Math.sol";

contract Vester_GetUnlockAmount is Vester_BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_calUnlockAmount(
        uint256 amount,
        uint256 duration
    ) external {
        // assuming maximum amount of esp88 to vest is 1e30
        vm.assume(amount < 1e30);
        vm.assume(duration > 0);
        vm.assume(duration <= 31536000);

        uint256 ratioX18 = (uint256(duration * 1e18)) / 31536000;
        uint256 sqrtRatioX18 = Math.sqrt(ratioX18) * 1e9;

        assertEq(
            (amount * ((ratioX18 * sqrtRatioX18) / 1e18)) / 1e18,
            vester.getUnlockAmount(amount, duration)
        );
    }
}
