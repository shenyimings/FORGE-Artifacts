//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/ELFeeRecipient.1.sol";
import "../src/libraries/Errors.sol";
import "../src/interfaces/IELFeeRecipient.1.sol";
import "../src/Withdraw.1.sol";
import "./utils/River.setup1.sol";
import "./utils/UserFactory.sol";

contract RiverDonationMock {
    event BalanceUpdated(uint256 amount);

    function sendELFees() external payable {
        emit BalanceUpdated(address(this).balance);
    }

    function pullELFees(address feeRecipient) external {
        IELFeeRecipientV1(payable(feeRecipient)).pullELFees();
    }
}

contract ELFeeRecipientV1Test {
    ELFeeRecipientV1 internal feeRecipient;

    RiverDonationMock internal river;
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    UserFactory internal uf = new UserFactory();

    event BalanceUpdated(uint256 amount);

    function setUp() public {
        river = new RiverDonationMock();
        feeRecipient = new ELFeeRecipientV1();
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
        river.pullELFees(address(feeRecipient));
    }

    function testPullFundsFromSend(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        assert(payable(address(feeRecipient)).send(_amount) == true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit BalanceUpdated(_amount);
        river.pullELFees(address(feeRecipient));
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
        river.pullELFees(address(feeRecipient));
    }

    function testPullFundsUnauthorized(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        payable(address(feeRecipient)).transfer(_amount);

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        feeRecipient.pullELFees();
        vm.stopPrank();
    }
}
