//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/ELFeeRecipient.1.sol";

contract RiverDonationMock {
    event BalanceUpdated(uint256 amount);

    function sendELFees() external payable {
        emit BalanceUpdated(address(this).balance);
    }

    function pullELFees(address feeRecipient, uint256 maxAmount) external {
        IELFeeRecipientV1(payable(feeRecipient)).pullELFees(maxAmount);
    }
}

contract ELFeeRecipientV1Test is Test {
    ELFeeRecipientV1 internal feeRecipient;

    RiverDonationMock internal river;
    UserFactory internal uf = new UserFactory();

    event BalanceUpdated(uint256 amount);
    event SetRiver(address indexed river);

    function setUp() public {
        river = new RiverDonationMock();
        feeRecipient = new ELFeeRecipientV1();
        LibImplementationUnbricker.unbrick(vm, address(feeRecipient));
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        feeRecipient.initELFeeRecipientV1(address(river));
    }

    function testPullFundsFromTransfer(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        payable(address(feeRecipient)).transfer(_amount);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit BalanceUpdated(_amount);
        river.pullELFees(address(feeRecipient), address(feeRecipient).balance);
    }

    function testPullFundsFromSend(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        assert(payable(address(feeRecipient)).send(_amount) == true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit BalanceUpdated(_amount);
        river.pullELFees(address(feeRecipient), address(feeRecipient).balance);
    }

    function testPullFundsFromCall(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        (bool ok,) = payable(address(feeRecipient)).call{value: _amount}("");
        assert(ok == true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit BalanceUpdated(_amount);
        river.pullELFees(address(feeRecipient), address(feeRecipient).balance);
    }

    function testPullHalfFunds(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        (bool ok,) = payable(address(feeRecipient)).call{value: _amount}("");
        assert(ok == true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit BalanceUpdated(_amount / 2);
        river.pullELFees(address(feeRecipient), address(feeRecipient).balance / 2);
    }

    function testPullFundsUnauthorized(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        payable(address(feeRecipient)).transfer(_amount);

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        feeRecipient.pullELFees(address(feeRecipient).balance);
        vm.stopPrank();
    }
}
