//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/state/redeemManager/RedeemQueue.sol";
import "../src/state/redeemManager/WithdrawalStack.sol";
import "../src/RedeemManager.1.sol";
import "../src/Allowlist.1.sol";

contract RiverMock {
    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal approvals;
    address internal allowlist;
    uint256 internal rate = 1e18;
    uint256 internal _totalSupply;

    constructor(address _allowlist) {
        allowlist = _allowlist;
    }

    function approve(address to, uint256 amount) external {
        approvals[msg.sender][to] = amount;
    }

    error ApprovedAmountTooLow();

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (approvals[from][msg.sender] < amount) {
            revert ApprovedAmountTooLow();
        }
        if (approvals[from][msg.sender] != type(uint256).max) {
            approvals[from][msg.sender] -= amount;
        }
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /// @notice Sets the balance of the given account and updates totalSupply
    /// @param account The account to set the balance of
    /// @param amount Amount to set as balance
    function sudoDeal(address account, uint256 amount) external {
        if (amount > balances[account]) {
            _totalSupply += amount - balances[account];
        } else {
            _totalSupply -= balances[account] - amount;
        }
        balances[account] = amount;
    }

    function sudoSetRate(uint256 newRate) external {
        rate = newRate;
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }

    function sudoReportWithdraw(address redeemManager, uint256 lsETHAmount) external payable {
        RedeemManagerV1(redeemManager).reportWithdraw{value: msg.value}(lsETHAmount);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalUnderlyingSupply() external view returns (uint256) {
        return (_totalSupply * rate) / 1e18;
    }

    function underlyingBalanceFromShares(uint256 shares) external view returns (uint256) {
        return (shares * rate) / 1e18;
    }
}

contract RedeemManagerV1Tests is Test {
    RedeemManagerV1 internal redeemManager;
    AllowlistV1 internal allowlist;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal allowlistAdmin;
    address internal allowlistAllower;

    event RequestedRedeem(address indexed owner, uint256 height, uint256 size, uint32 id);
    event ReportedWithdrawal(uint256 height, uint256 size, uint256 ethAmount, uint32 id);
    event SatisfiedRedeemRequest(
        uint32 indexed redeemRequestId,
        uint32 indexed withdrawalEventId,
        uint256 lsEthAmountSatisfied,
        uint256 ethAmountSatisfied,
        uint256 lsEthAmountRemaining,
        uint256 ethAmountExceeding
    );

    event ClaimedRedeemRequest(
        uint32 indexed redeemRequestId,
        address indexed recipient,
        uint256 ethAmount,
        uint256 lsEthAmount,
        uint256 remainingLsEthAmount
    );

    function setUp() external {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        redeemManager = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        river = new RiverMock(address(allowlist));

        redeemManager.initializeRedeemManagerV1(address(river));
    }

    function _generateAllowlistedUser(uint256 _salt) internal returns (address) {
        address user = uf._new(_salt);

        address[] memory accounts = new address[](1);
        uint256[] memory permissions = new uint256[](1);

        accounts[0] = user;
        permissions[0] = LibAllowlistMasks.REDEEM_MASK;

        vm.prank(allowlistAllower);
        allowlist.allow(accounts, permissions);

        return user;
    }

    function testRequestRedeem(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        assertEq(river.balanceOf(user), amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit RequestedRedeem(user, 0, amount, 0);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory requests = new uint32[](1);
        requests[0] = 0;

        assertEq(requests[0], 0);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, user);
            assertEq(rr.maxRedeemableEth, amount);
        }

        assertEq(river.balanceOf(user), 0);
        assertEq(redeemManager.getRedeemRequestCount(), 1);
    }

    function testRequestRedeemImplicitRecipient(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        assertEq(river.balanceOf(user), amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit RequestedRedeem(user, 0, amount, 0);
        redeemManager.requestRedeem(amount);

        uint32[] memory requests = new uint32[](1);
        requests[0] = 0;

        assertEq(requests[0], 0);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, user);
            assertEq(rr.maxRedeemableEth, amount);
        }

        assertEq(river.balanceOf(user), 0);
        assertEq(redeemManager.getRedeemRequestCount(), 1);
    }

    function testRequestRedeemUnauthorizedUser(uint256 _salt) external {
        address user = uf._new(_salt);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        redeemManager.requestRedeem(amount, user);
    }

    function testRequestRedeemMultiple(uint256 _salt) external {
        address user0 = _generateAllowlistedUser(_salt);
        address user1 = _generateAllowlistedUser(uint256(keccak256(abi.encode(_salt))));

        uint64 amount0 = uint64(bound(_salt, 1, type(uint64).max));
        uint64 amount1 = uint64(bound(uint256(keccak256(abi.encode(_salt))), 1, type(uint64).max));

        river.sudoDeal(user0, uint256(amount0));
        river.sudoDeal(user1, uint256(amount1));

        vm.prank(user0);
        river.approve(address(redeemManager), uint256(amount0));

        vm.prank(user1);
        river.approve(address(redeemManager), uint256(amount1));

        assertEq(river.balanceOf(user0), amount0);
        assertEq(river.balanceOf(user1), amount1);

        vm.prank(user0);
        redeemManager.requestRedeem(amount0, user0);

        vm.prank(user1);
        redeemManager.requestRedeem(amount1, user1);

        assertEq(river.balanceOf(user0), 0);
        assertEq(river.balanceOf(user1), 0);

        uint32[] memory requests = new uint32[](2);
        requests[0] = 0;
        requests[1] = 1;

        assertEq(requests[0], 0);
        assertEq(requests[1], 1);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount0);
            assertEq(rr.owner, user0);
        }

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount0);
            assertEq(rr.amount, amount1);
            assertEq(rr.owner, user1);
        }

        assertEq(redeemManager.getRedeemRequestCount(), 2);
    }

    function testRequestRedeemAmountZero(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAmount()"));
        redeemManager.requestRedeem(0, user);

        assertEq(redeemManager.getRedeemRequestCount(), 0);
    }

    function testRequestRedeemApproveTooLow(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

        uint64 amount = uint64(bound(_salt, 1, type(uint64).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount - 1);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("ApprovedAmountTooLow()"));
        redeemManager.requestRedeem(amount, user);

        assertEq(redeemManager.getRedeemRequestCount(), 0);
    }

    function testRequestRedeemZeroRecipient(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

        uint64 amount = uint64(bound(_salt, 1, type(uint64).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        redeemManager.requestRedeem(amount, address(0));

        assertEq(redeemManager.getRedeemRequestCount(), 0);
    }

    function testReportWithdraw(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(0, amount, amount, 0);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(address(redeemManager).balance, amount);
        assertEq(redeemManager.getWithdrawalEventCount(), 1);

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testReportWithdrawMultiple(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(0, amount, amount, 0);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(amount, amount, amount, 1);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 2);
        assertEq(address(redeemManager).balance, uint256(amount) * 2);

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequest(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequestWithImplicitSkipFlag(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequestTwiceWithSkipFlag(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        uint8[] memory claimStatus = redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        assertEq(claimStatus.length, 1);
        assertEq(claimStatus[0], 0);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        claimStatus = redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        assertEq(claimStatus.length, 1);
        assertEq(claimStatus[0], 2);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequestTwiceWithoutSkipFlag(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        uint32[] memory redeemRequestIds = new uint32[](2);
        uint32[] memory withdrawEventIds = new uint32[](2);

        redeemRequestIds[0] = 0;
        redeemRequestIds[1] = 0;
        withdrawEventIds[0] = 0;
        withdrawEventIds[1] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectRevert(abi.encodeWithSignature("RedeemRequestAlreadyClaimed(uint256)", 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, false);
    }

    function testClaimRedeemRequestContainedInsideWithdrawalEvent(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 2, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount) / 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) / 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount / 2, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount / 2);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;
        redeemRequestIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        assertEq(address(redeemManager).balance, amount - (amount / 2));
        assertEq(user.balance, amount / 2);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount / 2);
            assertEq(rr.amount, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequestTwiceBigger(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 2, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount / 2);
        river.sudoReportWithdraw{value: amount / 2}(address(redeemManager), amount / 2);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        assertEq(address(redeemManager).balance, amount / 2);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount / 2, amount / 2, amount - (amount / 2), 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount / 2, amount / 2, amount - (amount / 2));
        uint8[] memory claimStatuses = redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount / 2);
        assertEq(claimStatuses.length, 1);
        assertEq(claimStatuses[0], 1);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -1);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount / 2);
            assertEq(rr.amount, amount - (amount / 2));
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }
    }

    function testClaimRedeemRequestOnTwoEvents(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 2, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount / 2);
        river.sudoReportWithdraw{value: amount / 2}(address(redeemManager), amount / 2);

        vm.deal(address(this), amount - (amount / 2));
        river.sudoReportWithdraw{value: amount - (amount / 2)}(address(redeemManager), amount - (amount / 2));

        assertEq(redeemManager.getWithdrawalEventCount(), 2);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount / 2);
            assertEq(we.amount, amount - (amount / 2));
            assertEq(we.withdrawnEth, amount - (amount / 2));
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;
        redeemRequestIds[0] = 0;

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount / 2, amount / 2, amount - (amount / 2), 0);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 1, amount - (amount / 2), amount - (amount / 2), 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount / 2);
            assertEq(we.amount, amount - (amount / 2));
            assertEq(we.withdrawnEth, amount - (amount / 2));
        }
    }

    function testClaimRedeemRequestTwoRequestsOnOneEvent(uint256 _salt) external {
        uint256 amount = uint128(bound(_salt, 2, type(uint120).max));

        address user = _generateAllowlistedUser(_salt);
        address userB;
        unchecked {
            userB = uf._new(_salt + 1);
        }

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.prank(user);
        redeemManager.requestRedeem(amount, userB);

        vm.deal(address(this), amount * 2);
        river.sudoReportWithdraw{value: amount * 2}(address(redeemManager), amount * 2);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 2);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, user);
        }

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount);
            assertEq(rr.amount, amount);
            assertEq(rr.owner, userB);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount * 2);
            assertEq(we.withdrawnEth, amount * 2);
        }

        uint32[] memory redeemRequestIds = new uint32[](2);
        uint32[] memory withdrawEventIds = new uint32[](2);

        redeemRequestIds[0] = 1;
        redeemRequestIds[1] = 0;

        withdrawEventIds[0] = 0;
        withdrawEventIds[1] = 0;

        assertEq(address(redeemManager).balance, amount * 2);
        assertEq(user.balance, 0);
        assertEq(userB.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(1, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(1, userB, amount, amount, 0);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);
        assertEq(userB.balance, amount);

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.owner, user);
        }

        {
            RedeemQueue.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount * 2);
            assertEq(rr.amount, 0);
            assertEq(rr.owner, userB);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount * 2);
            assertEq(we.withdrawnEth, amount * 2);
        }
    }

    function testClaimRedeemRequestIncompatibleArrayLengths(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](0);

        redeemRequestIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("IncompatibleArrayLengths()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);
    }

    function testClaimRedeemRequestOutOfBounds(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("RedeemRequestOutOfBounds(uint256)", 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);
    }

    function testClaimRedeemRequestWithdrawalEventOutOfBounds(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("WithdrawalEventOutOfBounds(uint256)", 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);
    }

    function testClaimRedeemRequestNotMatching(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint120).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 1;
        withdrawEventIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("DoesNotMatch(uint256,uint256)", 1, 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);
    }

    function rollNext(uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_salt)));
    }

    function testFillingBothQueues(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);
        river.sudoDeal(address(this), 1e18);
        _salt = rollNext(_salt);
        uint256 totalAmount = bound(_salt, 1, type(uint64).max);
        uint256 filled = 0;
        uint256 salt = _salt;
        while (filled < totalAmount) {
            salt = rollNext(salt);
            uint256 eventSize = bound(salt, 1, type(uint64).max / 100);
            if (filled + eventSize > totalAmount) {
                eventSize = totalAmount - filled;
            }
            filled += eventSize;
            vm.deal(address(this), eventSize * 2);
            river.sudoReportWithdraw{value: eventSize * 2}(address(redeemManager), eventSize);
        }

        filled = 0;

        uint256 count = 0;
        while (filled < totalAmount) {
            salt = rollNext(salt);
            uint256 requestSize = bound(salt, 1, type(uint64).max / 500);

            if (filled + requestSize > totalAmount) {
                requestSize = totalAmount - filled;
            }
            filled += requestSize;

            river.sudoDeal(user, requestSize);

            vm.prank(user);
            river.approve(address(redeemManager), requestSize);

            vm.prank(user);
            redeemManager.requestRedeem(requestSize, user);
            ++count;
        }

        uint32[] memory redeemRequestIds = new uint32[](count);
        for (uint256 idx = 0; idx < count;) {
            redeemRequestIds[idx] = uint32(idx);
            unchecked {
                ++idx;
            }
        }
        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        uint32[] memory withdrawalEventIdsUint = new uint32[](withdrawalEventIds.length);

        for (uint256 idx = 0; idx < withdrawalEventIds.length;) {
            assertTrue(withdrawalEventIds[idx] >= 0, "unresolved requests");
            withdrawalEventIdsUint[idx] = uint32(uint64(withdrawalEventIds[idx]));
            console.log(redeemRequestIds[idx], uint32(uint64(withdrawalEventIds[idx])));
            unchecked {
                ++idx;
            }
        }

        assertEq(address(redeemManager).balance, totalAmount * 2);
        assertEq(user.balance, 0);

        uint8[] memory claimStatus = redeemManager.claimRedeemRequests(redeemRequestIds, withdrawalEventIdsUint, false);

        assertEq(address(redeemManager).balance, totalAmount);
        assertEq(user.balance, totalAmount);

        withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);

        for (uint256 idx = 0; idx < withdrawalEventIds.length;) {
            assertTrue(withdrawalEventIds[idx] == -3);
            assertTrue(claimStatus[idx] == 0);
            unchecked {
                ++idx;
            }
        }

        assertEq(redeemManager.getBufferedExceedingEth(), totalAmount);
    }

    function applyRate(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / 1e18;
    }

    function testClaimMultiRate() external {
        address user = _generateAllowlistedUser(0);

        uint256[] memory redeemRates = new uint256[](5);
        redeemRates[0] = 1_000_000_000_000_000_000;
        redeemRates[1] = 1_100_000_000_000_000_000;
        redeemRates[2] = 1_500_000_000_000_000_000;
        redeemRates[3] = 2_000_000_000_000_000_000;
        redeemRates[4] = 4_000_000_000_000_000_000;

        for (uint256 idx = 0; idx < redeemRates.length; ++idx) {
            uint256 amount = applyRate(100e18, redeemRates[idx]);
            vm.deal(address(this), amount);
            river.sudoReportWithdraw{value: amount}(address(redeemManager), 100e18);

            WithdrawalStack.WithdrawalEvent memory withdrawalEvent =
                redeemManager.getWithdrawalEventDetails(uint32(idx));

            assertEq(withdrawalEvent.height, idx * 100e18);
            assertEq(withdrawalEvent.amount, 100e18);
            assertEq(withdrawalEvent.withdrawnEth, applyRate(100e18, redeemRates[idx]));
        }

        uint256[] memory rates = new uint256[](15);
        rates[0] = 1_000_000_000_000_000_000;
        rates[1] = 1_000_000_000_000_000_000;
        rates[2] = 1_000_000_000_000_000_000;
        rates[3] = 1_000_000_000_000_000_000;

        rates[4] = 1_025_000_000_000_000_000;
        rates[5] = 1_050_000_000_000_000_000;
        rates[6] = 1_075_000_000_000_000_000;

        rates[7] = 1_200_000_000_000_000_000;
        rates[8] = 1_300_000_000_000_000_000;
        rates[9] = 1_400_000_000_000_000_000;

        rates[10] = 1_500_000_000_000_000_000;
        rates[11] = 1_600_000_000_000_000_000;
        rates[12] = 1_700_000_000_000_000_000;
        rates[13] = 1_900_000_000_000_000_000;

        rates[14] = 3_000_000_000_000_000_000;

        for (uint256 idx = 0; idx < rates.length; ++idx) {
            river.sudoSetRate(rates[idx]);
            river.sudoDeal(user, 30e18);

            vm.prank(user);
            river.approve(address(redeemManager), 30e18);

            vm.prank(user);
            redeemManager.requestRedeem(30e18, user);

            RedeemQueue.RedeemRequest memory redeemRequest = redeemManager.getRedeemRequestDetails(uint32(idx));

            assertEq(redeemRequest.height, idx * 30e18);
            assertEq(redeemRequest.amount, 30e18);
            assertEq(redeemRequest.owner, user);
            assertEq(redeemRequest.maxRedeemableEth, applyRate(30e18, rates[idx]));
        }

        uint256 exceedingAmount = 0;

        exceedingAmount += applyRate(30e18, redeemRates[0]) - applyRate(30e18, rates[0]);
        exceedingAmount += applyRate(30e18, redeemRates[0]) - applyRate(30e18, rates[1]);
        exceedingAmount += applyRate(30e18, redeemRates[0]) - applyRate(30e18, rates[2]);
        exceedingAmount += applyRate(10e18, redeemRates[0]) - applyRate(10e18, rates[3]);

        exceedingAmount += applyRate(20e18, redeemRates[1]) - applyRate(20e18, rates[3]);
        exceedingAmount += applyRate(30e18, redeemRates[1]) - applyRate(30e18, rates[4]);
        exceedingAmount += applyRate(30e18, redeemRates[1]) - applyRate(30e18, rates[5]);
        exceedingAmount += applyRate(20e18, redeemRates[1]) - applyRate(20e18, rates[6]);

        exceedingAmount += applyRate(10e18, redeemRates[2]) - applyRate(10e18, rates[6]);
        exceedingAmount += applyRate(30e18, redeemRates[2]) - applyRate(30e18, rates[7]);
        exceedingAmount += applyRate(30e18, redeemRates[2]) - applyRate(30e18, rates[8]);
        exceedingAmount += applyRate(30e18, redeemRates[2]) - applyRate(30e18, rates[9]);

        exceedingAmount += applyRate(30e18, redeemRates[3]) - applyRate(30e18, rates[10]);
        exceedingAmount += applyRate(30e18, redeemRates[3]) - applyRate(30e18, rates[11]);
        exceedingAmount += applyRate(30e18, redeemRates[3]) - applyRate(30e18, rates[12]);
        exceedingAmount += applyRate(10e18, redeemRates[3]) - applyRate(10e18, rates[13]);

        exceedingAmount += applyRate(20e18, redeemRates[4]) - applyRate(20e18, rates[13]);
        exceedingAmount += applyRate(30e18, redeemRates[4]) - applyRate(30e18, rates[14]);

        uint32[] memory ids = new uint32[](15);

        for (uint256 idx = 0; idx < ids.length; ++idx) {
            ids[idx] = uint32(idx);
        }

        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(ids);

        uint32[] memory withdrawalEventIdsU32 = new uint32[](withdrawalEventIds.length);
        for (uint256 idx = 0; idx < withdrawalEventIds.length; ++idx) {
            withdrawalEventIdsU32[idx] = uint32(uint64(withdrawalEventIds[idx]));
        }

        redeemManager.claimRedeemRequests(ids, withdrawalEventIdsU32);

        assertEq(redeemManager.getBufferedExceedingEth(), exceedingAmount);
    }

    function testResolveOutOfBounds() external {
        uint32[] memory redeemRequestIds = new uint32[](1);
        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        assertEq(withdrawalEventIds.length, 1);
        assertTrue(withdrawalEventIds[0] == -2);
    }

    function testResolveUnsatisfied(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint120).max));
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory redeemRequestIds = new uint32[](1);
        redeemRequestIds[0] = 0;

        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        assertEq(withdrawalEventIds.length, 1);
        assertTrue(withdrawalEventIds[0] == -1);
    }
}
