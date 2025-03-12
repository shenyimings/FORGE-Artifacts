// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseTest } from "./BaseTest.sol";
import { NPVToken } from "../src/tokens/NPVToken.sol";

contract NPVTokenTest is BaseTest {

    function testMintBurn() public {
        init();

        vm.startPrank(alice);
        NPVToken nt = new NPVToken("npvETH-GLP", "npvETH-GLP");
        nt.mint(alice, 1000);
        assertEq(nt.balanceOf(alice), 1000);
        nt.burn(alice, 100);
        assertEq(nt.balanceOf(alice), 900);
        vm.expectRevert("NPVT: insufficient balance");
        nt.burn(alice, 901);
        vm.expectRevert("NPVT: can only burn own");
        nt.burn(bob, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        nt.mint(bob, 1000);
        vm.expectRevert("Ownable: caller is not the owner");
        nt.burn(alice, 1);
        vm.stopPrank();
    }

}
