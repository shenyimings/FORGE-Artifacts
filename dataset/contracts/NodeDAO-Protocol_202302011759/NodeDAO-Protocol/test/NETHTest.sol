// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "src/tokens/NETH.sol";

contract NETHTest is Test {
    NETH neth;

    function setUp() public {
        neth = new NETH();
    }

    function testSetLiquidStaking() public {
        neth.setLiquidStaking(address(1));
        assertEq(address(1), neth.liquidStakingContract());
    }

    function testFailSetLiquidStaking() public {
        vm.prank(address(0));
        neth.setLiquidStaking(address(1));
        assertEq(address(1), neth.liquidStakingContract());
    }

    function testName() public {
        assertEq("Node ETH", neth.name());
    }

    function testSymbol() public {
        assertEq("nETH", neth.symbol());
    }

    function testWhiteListMint() public {
        neth.setLiquidStaking(address(1));
        vm.prank(address(1));
        neth.whiteListMint(1000000, address(2));
        assertEq(1000000, neth.balanceOf(address(2)));
    }

    function testFailWhiteListMint() public {
        neth.setLiquidStaking(address(1));
        neth.whiteListMint(1000000, address(2));
        assertEq(1000000, neth.balanceOf(address(2)));
    }

    function testWhiteListBurn() public {
        neth.setLiquidStaking(address(1));
        vm.prank(address(1));
        neth.whiteListMint(1000000, address(2));
        assertEq(1000000, neth.balanceOf(address(2)));

        vm.prank(address(1));
        neth.whiteListBurn(500000, address(2));
        assertEq(500000, neth.balanceOf(address(2)));
    }

    function testFailWhiteListBurn() public {
        neth.setLiquidStaking(address(1));
        vm.prank(address(1));
        neth.whiteListMint(1000000, address(2));
        assertEq(1000000, neth.balanceOf(address(2)));

        neth.whiteListBurn(500000, address(2));
    }
}
