// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/DOGA.sol";

contract DOGA_TEST is Test {
    DOGA public doga;
    address owner;

    function setUp() public {
        owner = address(0xabc);
        vm.startPrank(owner);
        doga = new DOGA("DOGA Token", "DOGA", 1000 * 10**18);
    }

    function test_Sender_should_own_doga() public {
        uint256 expectedBalance = 1000 * 10**18;
        uint256 actualBalance = doga.balanceOf(owner);
        assertEq(expectedBalance, actualBalance, "Balance are not matching");
    }
}
