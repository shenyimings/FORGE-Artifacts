// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { D03ProtocolDefaults, console2 } from "./defaults/D03ProtocolDefaults.sol";
import { DummyToken } from "./utils/DummyToken.sol";
import { LibERC20Fixture } from "./fixtures/LibERC20Fixture.sol";

contract T01LibERC20 is D03ProtocolDefaults {
    DummyToken private token;
    address private tokenAddress;

    LibERC20Fixture private fixture;
    address private fixtureAddress;

    function setUp() public virtual override {
        super.setUp();

        token = new DummyToken();
        tokenAddress = address(token);

        fixture = new LibERC20Fixture();
        fixtureAddress = address(fixture);
    }

    function testTransfer() public {
        token.mint(fixtureAddress, 100);
        assertEq(token.balanceOf(fixtureAddress), 100);
        assertEq(token.balanceOf(account0), 0);

        vm.expectRevert("LibERC20: ERC20 token address has no code");
        fixture.transfer(address(0), account0, 1);

        // failed transfer
        vm.expectRevert("not enough balance");
        fixture.transfer(tokenAddress, account0, 101);

        // failed transfer of 0
        vm.expectRevert("LibERC20: transfer or transferFrom returned false");
        fixture.transfer(tokenAddress, account0, 0);

        // successful transfer
        fixture.transfer(tokenAddress, account0, 100);

        assertEq(token.balanceOf(fixtureAddress), 0);
        assertEq(token.balanceOf(account0), 100);
    }

    function testTransferFrom() public {
        token.mint(signer1, 100);
        assertEq(token.balanceOf(signer1), 100);
        assertEq(token.balanceOf(account0), 0);

        vm.prank(signer1);
        token.approve(fixtureAddress, 200);
        assertEq(token.allowance(signer1, fixtureAddress), 200);

        vm.expectRevert("LibERC20: ERC20 token address has no code");
        fixture.transferFrom(address(0), signer1, account0, 1);

        // not enough allowance
        vm.expectRevert("not enough allowance");
        fixture.transferFrom(tokenAddress, account0, signer1, 201);

        // not enough balance
        vm.expectRevert("not enough balance");
        fixture.transferFrom(tokenAddress, signer1, account0, 101);

        // failed transfer of 0 reverts with empty string
        vm.expectRevert("LibERC20: transfer or transferFrom reverted");
        fixture.transferFrom(tokenAddress, signer1, account0, 0);

        // successful transfer
        fixture.transferFrom(tokenAddress, signer1, account0, 100);

        assertEq(token.balanceOf(signer1), 0);
        assertEq(token.balanceOf(account0), 100);
    }
}
