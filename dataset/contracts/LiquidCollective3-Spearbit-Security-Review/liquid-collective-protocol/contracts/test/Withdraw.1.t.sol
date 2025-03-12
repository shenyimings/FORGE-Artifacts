//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/interfaces/IWithdraw.1.sol";
import "../src/Withdraw.1.sol";

contract RiverMock {
    event DebugReceivedCLFunds(uint256 amount);

    function sendCLFunds() external payable {
        emit DebugReceivedCLFunds(msg.value);
    }

    function debug_pullFunds(address withdrawContract, uint256 amount) external {
        IWithdrawV1(payable(withdrawContract)).pullEth(amount);
    }
}

contract WithdrawV1Tests is Test {
    WithdrawV1 internal withdraw;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();

    event DebugReceivedCLFunds(uint256 amount);

    function setUp() external {
        river = new RiverMock();

        withdraw = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        withdraw.initializeWithdrawV1(address(river));
    }

    function testReinitialize() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        withdraw.initializeWithdrawV1(address(river));
    }

    function testGetCredentials() external {
        assertEq(
            withdraw.getCredentials(),
            bytes32(
                uint256(uint160(address(withdraw))) + 0x0100000000000000000000000000000000000000000000000000000000000000
            )
        );
    }

    function testGetRiver() external {
        assertEq(withdraw.getRiver(), address(river));
    }

    function testPullFundsAsRiverPullAll(uint256 _amount) external {
        vm.deal(address(withdraw), _amount);

        assertEq(address(withdraw).balance, _amount);
        assertEq(address(river).balance, 0);

        vm.expectEmit(true, true, true, true);
        emit DebugReceivedCLFunds(_amount);
        river.debug_pullFunds(address(withdraw), _amount);

        assertEq(address(withdraw).balance, 0);
        assertEq(address(river).balance, _amount);
    }

    function testSendingFundsReverting(uint256 _amount) external {
        address sender = uf._new(_amount);
        vm.deal(sender, _amount);

        vm.startPrank(sender);

        assertEq(sender.balance, _amount);
        assertEq(address(withdraw).balance, 0);

        assertEq(payable(address(withdraw)).send(_amount), false);

        assertEq(sender.balance, _amount);
        assertEq(address(withdraw).balance, 0);

        vm.expectRevert();
        payable(address(withdraw)).transfer(_amount);

        assertEq(sender.balance, _amount);
        assertEq(address(withdraw).balance, 0);

        (bool success,) = payable(address(withdraw)).call{value: _amount}("");
        assertEq(success, false);

        assertEq(sender.balance, _amount);
        assertEq(address(withdraw).balance, 0);

        vm.stopPrank();
    }

    function testPullFundsAsRiverPullPartial(uint256 _salt, uint256 _amount) external {
        vm.assume(_amount > 0);
        vm.deal(address(withdraw), _amount);

        assertEq(address(withdraw).balance, _amount);
        assertEq(address(river).balance, 0);

        uint256 amountToPull = bound(_salt, 1, _amount);

        vm.expectEmit(true, true, true, true);
        emit DebugReceivedCLFunds(amountToPull);
        river.debug_pullFunds(address(withdraw), amountToPull);

        assertEq(address(withdraw).balance, _amount - amountToPull);
        assertEq(address(river).balance, amountToPull);
    }

    function testPullFundsAsRandom(uint256 _salt) external {
        address random = uf._new(_salt);

        vm.deal(address(withdraw), 1 ether);

        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        withdraw.pullEth(1 ether);
    }

    function testPullFundsAmountTooHigh(uint256 _amount) external {
        _amount = bound(_amount, 1, type(uint128).max);

        vm.deal(address(withdraw), _amount);

        assertEq(address(withdraw).balance, uint256(_amount));
        assertEq(address(river).balance, 0);

        river.debug_pullFunds(address(withdraw), _amount * 2);

        assertEq(address(withdraw).balance, 0);
        assertEq(address(river).balance, _amount);
    }
}
