//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/state/shared/RiverAddress.sol";
import "../src/state/redeemManager/RedeemDemand.sol";
import "../src/state/redeemManager/RedeemQueue.1.sol";
import "../src/state/redeemManager/RedeemQueue.2.sol";
import "../src/state/redeemManager/RedeemQueue.1.2.sol";

import "../src/state/redeemManager/WithdrawalStack.sol";
import "../src/RedeemManager.1.sol";
import "../src/TUPProxy.sol";
import "../src/Initializable.sol";
import "../src/Allowlist.1.sol";
import "./mocks/RejectEtherMock.sol";

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

    function pullExceedingEth(address redeemManager, uint256 amount) external {
        RedeemManagerV1(redeemManager).pullExceedingEth(amount);
    }

    fallback() external payable {}
}

contract RedeeManagerV1TestBase is Test {
    AllowlistV1 internal allowlist;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal allowlistAdmin;
    address internal allowlistAllower;
    address internal allowlistDenier;
    address public mockRiverAddress;
    bytes32 internal constant REDEEM_QUEUE_ID_SLOT = bytes32(uint256(keccak256("river.state.redeemQueue")) - 1);

    event RequestedRedeem(address indexed recipient, uint256 height, uint256 size, uint256 maxRedeemableEth, uint32 id);
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
}

contract RedeemManagerV1Tests is RedeeManagerV1TestBase {
    RedeemManagerV1 internal redeemManager;

    function setUp() external {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        redeemManager = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);
        river = new RiverMock(address(allowlist));

        redeemManager.initializeRedeemManagerV1(address(river));
    }

    // allowlist a user
    function _allowlistUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function _generateAllowlistedUser(uint256 _salt) internal returns (address) {
        address user = uf._new(_salt);
        _allowlistUser(user);
        return user;
    }

    function _denyUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DENY_MASK;

        vm.prank(allowlistDenier);
        allowlist.setDenyPermissions(accounts, permissions);
    }

    function _unDenyUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = 0;

        vm.prank(allowlistDenier);
        allowlist.setDenyPermissions(accounts, permissions);
    }

    function testGetRiver() public view {
        assert(redeemManager.getRiver() == address(river));
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
        emit RequestedRedeem(user, 0, amount, amount, 0);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory requests = new uint32[](1);
        requests[0] = 0;

        assertEq(requests[0], 0);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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
        emit RequestedRedeem(user, 0, amount, amount, 0);
        redeemManager.requestRedeem(amount);

        uint32[] memory requests = new uint32[](1);
        requests[0] = 0;

        assertEq(requests[0], 0);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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

    function testRequestRedeemWithAuthorizedRecipient(uint256 _salt, uint256 _salt2) external {
        vm.assume(_salt != _salt2);
        address user = _generateAllowlistedUser(_salt);
        address recipient = uf._new(_salt2);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        assertEq(river.balanceOf(user), amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit RequestedRedeem(recipient, 0, amount, amount, 0);
        redeemManager.requestRedeem(amount, recipient);

        uint32[] memory requests = new uint32[](1);
        requests[0] = 0;

        assertEq(requests[0], 0);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, recipient);
            assertEq(rr.maxRedeemableEth, amount);
        }

        assertEq(river.balanceOf(user), 0);
        assertEq(redeemManager.getRedeemRequestCount(), 1);
    }

    function testRequestRedeemUnauthorizedRecipient(uint256 _salt, uint256 _salt2) external {
        vm.assume(_salt != _salt2);
        address user = _generateAllowlistedUser(_salt);
        address recipient = uf._new(_salt2);
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        _denyUser(recipient);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("RecipientIsDenied()"));
        redeemManager.requestRedeem(amount, recipient);
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount0);
            assertEq(rr.recipient, user0);
        }

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount0);
            assertEq(rr.amount, amount1);
            assertEq(rr.recipient, user1);
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
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

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

    function testReportWithdrawFail(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);

        vm.expectRevert(
            abi.encodeWithSignature(
                "WithdrawalExceedsRedeemDemand(uint256,uint256)", uint256(amount) + 1e18, uint256(amount)
            )
        );
        river.sudoReportWithdraw{value: amount}(address(redeemManager), uint256(amount) + 1e18);
    }

    function testReportWithdrawMultiple(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(uint256(amount) * 2, user);

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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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
        uint8[] memory claimStatus =
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        assertEq(claimStatus.length, 1);
        assertEq(claimStatus[0], 0);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        claimStatus = redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(claimStatus.length, 1);
        assertEq(claimStatus[0], 2);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, false, type(uint16).max);
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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
        uint8[] memory claimStatuses =
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount / 2);
        assertEq(claimStatuses.length, 1);
        assertEq(claimStatuses[0], 1);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount / 2);
            assertEq(rr.amount, amount - (amount / 2));
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }
    }

    function testClaimRedeemRequestOnMultipleEventsCustomDepths(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 10, type(uint128).max / 10));
        amount *= 10;

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);

        assertEq(redeemManager.getWithdrawalEventCount(), 10);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;
        redeemRequestIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        uint256 remaining = amount - (amount / 10);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount / 10, amount / 10, remaining, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount / 10, amount / 10, remaining);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, 0);

        RedeemQueueV2.RedeemRequest memory redeemRequest = redeemManager.getRedeemRequestDetails(0);
        assertEq(redeemRequest.height, amount - remaining);
        assertEq(redeemRequest.amount, remaining);

        withdrawEventIds[0] = 1;

        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 1, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 2, amount / 10, amount / 10, remaining, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, 2 * (amount / 10), 2 * (amount / 10), remaining);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, 1);

        redeemRequest = redeemManager.getRedeemRequestDetails(0);
        assertEq(redeemRequest.height, amount - remaining);
        assertEq(redeemRequest.amount, remaining);

        withdrawEventIds[0] = 3;

        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 3, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 4, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 5, amount / 10, amount / 10, remaining, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, 3 * (amount / 10), 3 * (amount / 10), remaining);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, 2);

        redeemRequest = redeemManager.getRedeemRequestDetails(0);
        assertEq(redeemRequest.height, amount - remaining);
        assertEq(redeemRequest.amount, remaining);

        withdrawEventIds[0] = 6;

        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 6, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 7, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 8, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 9, amount / 10, amount / 10, remaining, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, 4 * (amount / 10), 4 * (amount / 10), remaining);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, 3);

        redeemRequest = redeemManager.getRedeemRequestDetails(0);
        assertEq(redeemRequest.height, amount - remaining);
        assertEq(redeemRequest.amount, remaining);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, userB);
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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);
        assertEq(userB.balance, amount);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
        }

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount * 2);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, userB);
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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function testClaimRedeemRequestOutOfBounds() external {
        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("RedeemRequestOutOfBounds(uint256)", 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
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
        uint256 count = 0;
        uint256 salt = _salt;

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

        assertEq(redeemManager.getRedeemDemand(), totalAmount);

        filled = 0;
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

        assertEq(redeemManager.getRedeemDemand(), 0);

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
            unchecked {
                ++idx;
            }
        }

        assertEq(address(redeemManager).balance, totalAmount * 2);
        assertEq(user.balance, 0);

        uint8[] memory claimStatus =
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawalEventIdsUint, false, type(uint16).max);

        assertEq(address(redeemManager).balance, totalAmount);
        assertEq(user.balance, totalAmount);
        assertEq(redeemManager.getRedeemDemand(), 0);

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

        uint256[] memory rates = new uint256[](10);
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

        for (uint256 idx = 0; idx < rates.length; ++idx) {
            river.sudoSetRate(rates[idx]);
            river.sudoDeal(user, 30e18);

            vm.prank(user);
            river.approve(address(redeemManager), 30e18);

            vm.prank(user);
            redeemManager.requestRedeem(30e18, user);

            RedeemQueueV2.RedeemRequest memory redeemRequest = redeemManager.getRedeemRequestDetails(uint32(idx));

            assertEq(redeemRequest.height, idx * 30e18);
            assertEq(redeemRequest.amount, 30e18);
            assertEq(redeemRequest.recipient, user);
            assertEq(redeemRequest.maxRedeemableEth, applyRate(30e18, rates[idx]));
        }

        uint256[] memory redeemRates = new uint256[](3);
        redeemRates[0] = 1_000_000_000_000_000_000;
        redeemRates[1] = 1_100_000_000_000_000_000;
        redeemRates[2] = 1_500_000_000_000_000_000;

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

        uint32[] memory ids = new uint32[](10);

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

    function testResolveRedeemRequestForZeroIds() external {
        uint32[] memory redeemRequestIds = new uint32[](0);
        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        assert(withdrawalEventIds.length == 0);
    }

    function testPullExceedingEth() external {
        vm.deal(address(redeemManager), 1 ether);
        vm.store(
            address(redeemManager),
            bytes32(uint256(keccak256("river.state.bufferedExceedingEth")) - 1),
            bytes32(uint256(1 ether))
        );
        river.pullExceedingEth(address(redeemManager), 1 ether);
    }

    function testClaimRedeemRequestFailsWithDeniedUser(uint256 _salt) external {
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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

        _denyUser(user);

        // A user can't claim if the recipient is denied
        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        // The denied user can't claim
        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        vm.prank(user);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    // A claimRedeemRequest for a redeemRequest whose initiator is denied should fail
    function testClaimRedeemRequestFailsWithDeniedInitiator(uint256 _salt, uint256 _salt2) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);
        address initiator = _generateAllowlistedUser(_salt2); // Generate a different initiator

        river.sudoDeal(initiator, uint256(amount));

        vm.prank(initiator);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(initiator);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
            assertEq(rr.initiator, initiator); // Check the initiator
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

        _denyUser(initiator);

        // A user can't claim if the initiator is denied
        vm.expectRevert(abi.encodeWithSignature("ClaimInitiatorIsDenied()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        // The allowed recipient can't claim, if the initiator is denied
        vm.expectRevert(abi.encodeWithSignature("ClaimInitiatorIsDenied()"));
        vm.prank(user);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    // A denied user when undenied would be able to claim the ETH
    function testClaimRedeemRequestClaimsWithDeniedUserUndenied(uint256 _salt) external {
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
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

        _denyUser(user);

        // A user can't claim if the recipient is denied
        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        // The denied user can't claim
        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        vm.prank(user);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        _unDenyUser(user);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    // The ETH remains behind in the protocol
    // Submit 2 different redeem requests from different users
    // One user gets denied
    // Other user claims
    // The balance of redeem manager shows the unclaimable ETH
    function testUnclaimableDeniedETHRemainsInProtocol(uint256 _salt, uint256 _salt2) external {
        vm.assume(_salt != _salt2);

        uint128 amount = uint128(bound(_salt, 1, type(uint64).max));

        address user = _generateAllowlistedUser(_salt);
        address user2 = _generateAllowlistedUser(_salt2);

        {
            river.sudoDeal(user, uint256(amount));
            river.sudoDeal(user2, uint256(amount));

            vm.prank(user);
            river.approve(address(redeemManager), uint256(amount));

            vm.prank(user);
            redeemManager.requestRedeem(amount, user);

            vm.prank(user2);
            river.approve(address(redeemManager), uint256(amount));

            vm.prank(user2);
            redeemManager.requestRedeem(amount, user2);

            vm.deal(address(this), amount);
            river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

            vm.deal(address(this), amount);
            river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);
        }

        assertEq(redeemManager.getWithdrawalEventCount(), 2);
        assertEq(redeemManager.getRedeemRequestCount(), 2);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount * 2);
        assertEq(user.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        _denyUser(user2);

        vm.prank(user);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, amount);

        redeemRequestIds[0] = 1;
        withdrawEventIds[0] = 1;

        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        vm.prank(user2);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    // ClaimedRedeemRequest event should be emitted when a redeem request is claimed
    function testClaimRedeemRequestEmitsClaimedEvent(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint64).max));
        address initiator = _generateAllowlistedUser(_salt);

        river.sudoDeal(initiator, uint256(amount));

        vm.prank(initiator);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(initiator);
        redeemManager.requestRedeem(amount, initiator);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, initiator);
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
        assertEq(initiator.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        // Assume the initiator and recipient to be same
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, initiator, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function testClaimRedeemRequestRevertsOnFailedEtherTransferToRecipient(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address initiator = _generateAllowlistedUser(_salt);

        // Deploy the RejectEtherMock contract for recipient
        address recipient = address(new RejectEtherMock());
        _allowlistUser(recipient);

        // Fund the initiator
        river.sudoDeal(initiator, uint256(amount));

        // Approve and request redeem with the initiator
        vm.prank(initiator);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(initiator);
        redeemManager.requestRedeem(amount, recipient);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, recipient);
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
        assertEq(initiator.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        // Attempt to claim the redeem request and expect it to fail
        vm.expectRevert(abi.encodeWithSignature("ClaimRedeemFailed(address,bytes)", recipient, new bytes(0)));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function testVersion() external {
        assertEq(redeemManager.version(), "1.2.1");
    }
}

interface IRedeemManagerV1Mock {
    event RequestedRedeem(
        address indexed recipient, uint256 height, uint256 amount, uint256 maxRedeemableEth, uint32 id
    );

    event SetRedeemDemand(uint256 oldRedeemDemand, uint256 newRedeemDemand);

    event SetRiver(address river);

    /// @notice Thrown When a zero value is provided
    error InvalidZeroAmount();

    /// @notice Thrown when a transfer error occured with LsETH
    error TransferError();

    /// @notice Thrown when the provided arrays don't have matching lengths
    error IncompatibleArrayLengths();

    error RedeemRequestOutOfBounds(uint256 id);

    error DoesNotMatch(uint256 redeemRequestId, uint256 withdrawalEventId);

    /// @notice Thrown when the recipient of redeemRequest is denied
    error RecipientIsDenied();
}

contract MockRedeemManagerV1Base is Initializable, IRedeemManagerV1Mock {
    modifier onlyRedeemerOrRiver() {
        {
            IRiverV1 river = _castedRiver();
            if (msg.sender != address(river)) {
                IAllowlistV1(river.getAllowlist()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
            }
        }
        _;
    }

    function initializeRedeemManagerV1(address _river) external init(0) {
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    function _setRedeemDemand(uint256 _newValue) internal {
        emit SetRedeemDemand(RedeemDemand.get(), _newValue);
        RedeemDemand.set(_newValue);
    }

    function _castedRiver() internal view returns (IRiverV1) {
        return IRiverV1(payable(RiverAddress.get()));
    }
}

contract MockRedeemManagerV1 is MockRedeemManagerV1Base {
    function getRedeemRequestDetails(uint32 _redeemRequestId)
        external
        view
        returns (RedeemQueueV1.RedeemRequest memory)
    {
        return RedeemQueueV1.get()[_redeemRequestId];
    }

    function requestRedeem(uint256 _lsETHAmount, address _recipient)
        external
        onlyRedeemerOrRiver
        returns (uint32 redeemRequestId)
    {
        IRiverV1 river = _castedRiver();
        if (IAllowlistV1(river.getAllowlist()).isDenied(_recipient)) {
            revert RecipientIsDenied();
        }
        return _requestRedeem(_lsETHAmount, _recipient);
    }

    function _requestRedeem(uint256 _lsETHAmount, address _recipient) internal returns (uint32 redeemRequestId) {
        LibSanitize._notZeroAddress(_recipient);
        if (_lsETHAmount == 0) {
            revert InvalidZeroAmount();
        }
        if (!_castedRiver().transferFrom(msg.sender, address(this), _lsETHAmount)) {
            revert TransferError();
        }
        RedeemQueueV1.RedeemRequest[] storage redeemRequests = RedeemQueueV1.get();
        redeemRequestId = uint32(redeemRequests.length);
        uint256 height = 0;
        if (redeemRequestId != 0) {
            RedeemQueueV1.RedeemRequest memory previousRedeemRequest = redeemRequests[redeemRequestId - 1];
            height = previousRedeemRequest.height + previousRedeemRequest.amount;
        }

        uint256 maxRedeemableEth = _castedRiver().underlyingBalanceFromShares(_lsETHAmount);

        redeemRequests.push(
            RedeemQueueV1.RedeemRequest({
                height: height,
                amount: _lsETHAmount,
                recipient: _recipient,
                maxRedeemableEth: maxRedeemableEth
            })
        );

        _setRedeemDemand(RedeemDemand.get() + _lsETHAmount);

        emit RequestedRedeem(_recipient, height, _lsETHAmount, maxRedeemableEth, redeemRequestId);
    }
}

contract MockRedeemManagerV1_2 is MockRedeemManagerV1Base {
    function getRedeemRequestDetails(uint32 _redeemRequestId)
        external
        view
        returns (RedeemQueueV1_2.RedeemRequest memory)
    {
        return RedeemQueueV1_2.get()[_redeemRequestId];
    }

    function requestRedeem(uint256 _lsETHAmount, address _recipient)
        external
        onlyRedeemerOrRiver
        returns (uint32 redeemRequestId)
    {
        IRiverV1 river = _castedRiver();
        if (IAllowlistV1(river.getAllowlist()).isDenied(_recipient)) {
            revert RecipientIsDenied();
        }
        return _requestRedeem(_lsETHAmount, _recipient);
    }

    function _requestRedeem(uint256 _lsETHAmount, address _recipient) internal returns (uint32 redeemRequestId) {
        LibSanitize._notZeroAddress(_recipient);
        if (_lsETHAmount == 0) {
            revert InvalidZeroAmount();
        }
        if (!_castedRiver().transferFrom(msg.sender, address(this), _lsETHAmount)) {
            revert TransferError();
        }
        RedeemQueueV1_2.RedeemRequest[] storage redeemRequests = RedeemQueueV1_2.get();
        redeemRequestId = uint32(redeemRequests.length);
        uint256 height = 0;
        if (redeemRequestId != 0) {
            RedeemQueueV1_2.RedeemRequest memory previousRedeemRequest = redeemRequests[redeemRequestId - 1];
            height = previousRedeemRequest.height + previousRedeemRequest.amount;
        }

        uint256 maxRedeemableEth = _castedRiver().underlyingBalanceFromShares(_lsETHAmount);

        redeemRequests.push(
            RedeemQueueV1_2.RedeemRequest({
                height: height,
                amount: _lsETHAmount,
                recipient: _recipient,
                initiator: msg.sender,
                maxRedeemableEth: maxRedeemableEth
            })
        );

        _setRedeemDemand(RedeemDemand.get() + _lsETHAmount);

        emit RequestedRedeem(_recipient, height, _lsETHAmount, maxRedeemableEth, redeemRequestId);
    }
}

contract InitializeRedeemManagerV1_2Test is RedeeManagerV1TestBase {
    address[] public prevInitiators;
    address public admin = address(0x123);
    address redeemManager;

    bytes32 constant REDEEM_QUEUE_V1_SLOT = bytes32(uint256(keccak256("river.state.redeemQueue")) - 1);
    bytes32 constant INITIALIZABLE_STORAGE_SLOT = bytes32(uint256(keccak256("openzeppelin.storage.Initializable")) - 1);
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // allowlist a user
    function _allowlistUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function setUp() public {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);
        river = new RiverMock(address(allowlist));

        MockRedeemManagerV1 redeemQueueImplV1 = new MockRedeemManagerV1();
        TUPProxy proxy = new TUPProxy(
            address(redeemQueueImplV1), admin, abi.encodeWithSignature("initializeRedeemManagerV1(address)", river)
        );
        redeemManager = address(proxy);

        // Setup prevInitiators
        for (uint256 i = 0; i < 7; i++) {
            prevInitiators.push(address(uint160(i + 1)));
        }

        // Setup initial queue (RedeemQueueV1)
        for (uint256 i = 0; i < 7; i++) {
            address user = address(uint160(i + 100));
            _allowlistUser(user);
            uint128 amount = uint128((i + 1) * 1e18);
            river.sudoDeal(user, amount);

            vm.prank(user);
            river.approve(address(redeemManager), amount);
            assertEq(river.balanceOf(user), amount);
            vm.prank(user);
            MockRedeemManagerV1(redeemManager).requestRedeem(amount, user);
        }

        // Setup current queue (RedeemQueueV1_2)
        MockRedeemManagerV1_2 redeemQueueImplV1_2 = new MockRedeemManagerV1_2();
        vm.store(redeemManager, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(redeemQueueImplV1_2)))));
        for (uint256 i = 0; i < 8; i++) {
            address user = address(uint160(i + 200));
            _allowlistUser(user);
            uint128 amount = uint128((i + 2) * 1e18);
            river.sudoDeal(user, amount);

            vm.prank(user);
            river.approve(address(redeemManager), amount);
            assertEq(river.balanceOf(user), amount);
            vm.prank(user);
            MockRedeemManagerV1_2(redeemManager).requestRedeem(amount, user);
        }
    }

    function testInitializeTwice() public {
        RedeemManagerV1 redeemQueueImplV2 = new RedeemManagerV1();
        vm.store(redeemManager, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(redeemQueueImplV2)))));
        RedeemManagerV1(redeemManager).initializeRedeemManagerV1_2(prevInitiators);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 1, 2));
        RedeemManagerV1(redeemManager).initializeRedeemManagerV1_2(prevInitiators);
    }

    function testRedeemQueueMigrationV1_2() public {
        // Call the migration function
        RedeemManagerV1 redeemQueueImplV2 = new RedeemManagerV1();
        vm.store(redeemManager, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(redeemQueueImplV2)))));
        RedeemManagerV1(redeemManager).initializeRedeemManagerV1_2(prevInitiators);

        // Check the first 7 entries (from initialQueue)
        for (uint256 i = 0; i < 7; i++) {
            RedeemQueueV2.RedeemRequest memory current =
                RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i));
            assertEq(current.amount, (i + 1) * 1e18);
            // assertEq(current.maxRedeemableEth, i * 2e18);
            assertEq(current.recipient, address(uint160(i + 100)));
            if (i == 0) {
                assertEq(current.height, 0);
            } else {
                uint256 prevHeight = RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i - 1)).height;
                uint256 prevAmount = RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i - 1)).amount;
                assertEq(current.height, prevHeight + prevAmount);
            }
            assertEq(current.initiator, prevInitiators[i]);
        }

        // Check the remaining entries (from currentQueue)
        for (uint256 i = 7; i < 15; i++) {
            RedeemQueueV2.RedeemRequest memory current =
                RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i));
            assertEq(current.amount, ((i - 7) + 2) * 1e18);
            // assertEq(current.maxRedeemableEth, (i - 7) * 2e18);
            assertEq(current.recipient, address(uint160((i - 7) + 200)));
            uint256 prevHeight = RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i - 1)).height;
            uint256 prevAmount = RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i - 1)).amount;
            assertEq(current.initiator, current.recipient);
        }

        // Check total length
        assertEq(RedeemManagerV1(redeemManager).getRedeemRequestCount(), 15);
    }

    function testRedeemQueueMigrationV2_IncompatibleArrayLengths() public {
        // Test with incompatible array length
        address[] memory invalidInitiators = new address[](6);

        // Call the migration function
        RedeemManagerV1 redeemQueueImplV2 = new RedeemManagerV1();
        vm.store(redeemManager, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(redeemQueueImplV2)))));
        vm.expectRevert(abi.encodeWithSignature("IncompatibleArrayLengths()"));
        RedeemManagerV1(redeemManager).initializeRedeemManagerV1_2(invalidInitiators);
    }
}
