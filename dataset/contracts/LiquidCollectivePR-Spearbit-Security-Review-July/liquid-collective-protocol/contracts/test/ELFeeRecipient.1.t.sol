//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

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

abstract contract ELFeeRecipientV1TestBase is Test {
    ELFeeRecipientV1 internal feeRecipient;

    RiverDonationMock internal river;
    UserFactory internal uf = new UserFactory();

    event BalanceUpdated(uint256 amount);
    event SetRiver(address indexed river);
}

contract ELFeeRecipientV1InitializationTests is ELFeeRecipientV1TestBase {
    function setUp() public {
        river = new RiverDonationMock();
        feeRecipient = new ELFeeRecipientV1();
        LibImplementationUnbricker.unbrick(vm, address(feeRecipient));
    }

    function testInitialization() external {
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        feeRecipient.initELFeeRecipientV1(address(river));
    }
}

contract ELFeeRecipientV1Test is ELFeeRecipientV1TestBase {
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

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount);
        }
        river.pullELFees(address(feeRecipient), address(feeRecipient).balance);
    }

    function testPullFundsFromSend(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        assert(payable(address(feeRecipient)).send(_amount) == true);
        vm.stopPrank();

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount);
        }
        river.pullELFees(address(feeRecipient), address(feeRecipient).balance);
    }

    function testPullFundsFromCall(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        (bool ok,) = payable(address(feeRecipient)).call{value: _amount}("");
        assert(ok == true);
        vm.stopPrank();

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount);
        }
        river.pullELFees(address(feeRecipient), address(feeRecipient).balance);
    }

    function testPullHalfFunds(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        (bool ok,) = payable(address(feeRecipient)).call{value: _amount}("");
        assert(ok == true);
        vm.stopPrank();

        if (_amount / 2 > 0) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount / 2);
        }
        river.pullELFees(address(feeRecipient), address(feeRecipient).balance / 2);
    }

    function testNoFundPulled() external {
        vm.deal(address(feeRecipient), 0);
        river.pullELFees(address(feeRecipient), 0);
        assertEq(0, address(river).balance);
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

    function testFallbackFail() external {
        address sender = uf._new(1);
        vm.deal(sender, 1e18);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        address(feeRecipient).call{value: 1e18}(abi.encodeWithSignature("Hello()"));
        vm.stopPrank();
    }

    function testVersion() external {
        assertEq(feeRecipient.version(), "1.2.1");
    }
}
