// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicTest.sol";
import "../contracts/tokenomics/CNCLockerV2Wrapper.sol";

contract CNCLockerV2Test is ConicTest {
    event Locked(address indexed account, uint256 amount, uint256 unlockTime, bool relocked);

    Controller public controller;
    CNCLockerV2 public locker;
    CNCToken public cnc;

    function setUp() public override {
        super.setUp();

        controller = _createAndInitializeController();
        cnc = CNCToken(controller.cncToken());
        locker = _createLockerV2(controller);
        cnc.mint(address(bb8), 100_000e18);
        vm.prank(bb8);
        cnc.approve(address(locker), 100_000e18);

        vm.mockCall(
            locker.V1_LOCKER(),
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(0)
        );
    }

    function testInitialState() public {
        assertEq(address(locker.controller()), address(controller));
    }

    function testLock() public {
        vm.startPrank(bb8);
        vm.expectEmit(true, false, false, true);
        emit Locked(bb8, 1_000e18, block.timestamp + 120 days, false);
        locker.lock(1_000e18, 120 days);
        assertEq(locker.totalLocked(), 1_000e18);
        assertEq(locker.lockedBalance(bb8), 1_000e18);
        assertEq(locker.balanceOf(bb8), 1_000e18);
        assertEq(cnc.balanceOf(address(locker)), 1_000e18);
        assertEq(cnc.balanceOf(bb8), 99_000e18);
        CNCLockerV2.VoteLock[] memory locks = locker.userLocks(bb8);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 1_000e18);
        assertEq(locks[0].unlockTime, block.timestamp + 120 days);
        assertEq(locker.unlockableBalance(bb8), 0);
    }

    function testLockerWrapper() public {
        Controller newController = _createAndInitializeController();
        CNCLockerV2Wrapper wrapper = new CNCLockerV2Wrapper(newController, locker);
        vm.startPrank(bb8);
        locker.lock(1_000e18, 120 days);
        assertEq(wrapper.balanceOf(bb8), 1_000e18);
        address tokenStaker = address(newController.lpTokenStaker());
        vm.mockCall(
            tokenStaker,
            abi.encodeWithSelector(LpTokenStaker.getBoost.selector, bb8),
            abi.encode(2e18)
        );
        assertEq(wrapper.balanceOf(bb8), 2_000e18);
        assertEq(locker.balanceOf(bb8), 1_000e18);
        skip(120 days);
        locker.executeAvailableUnlocks();
        assertEq(wrapper.balanceOf(bb8), 0);
    }

    function testLockInvalidTime() public {
        vm.startPrank(bb8);
        vm.expectRevert("lock time invalid");
        locker.lock(1_000e18, 90 days);
        vm.expectRevert("lock time invalid");
        locker.lock(1_000e18, 365 days);
    }

    function testLockMultiple() public {
        vm.startPrank(bb8);
        locker.lock(1_000e18, 120 days);
        skip(20 days);
        locker.lock(2_000e18, 200 days);
        assertEq(locker.totalLocked(), 3_000e18);
        skip(30 days);
        locker.lock(10_000e18, 220 days);

        assertEq(locker.unlockableBalance(bb8), 0);
        assertEq(locker.totalLocked(), 13_000e18);

        CNCLockerV2.VoteLock[] memory locks = locker.userLocks(bb8);
        assertEq(locks.length, 3);
        assertEq(locks[0].unlockTime, block.timestamp + 70 days);
        assertEq(locks[1].unlockTime, block.timestamp + 170 days);
        assertEq(locks[2].unlockTime, block.timestamp + 220 days);
    }

    function testLockMultipleWithRelock() public {
        vm.startPrank(bb8);
        locker.lock(1_000e18, 120 days);
        skip(20 days);

        locker.lock(2_000e18, 200 days, true);
        assertEq(locker.totalLocked(), 3_000e18);
        CNCLockerV2.VoteLock[] memory locks = locker.userLocks(bb8);
        assertEq(locks.length, 1);
        assertEq(locks[0].unlockTime, block.timestamp + 200 days);

        skip(50 days);
        vm.expectRevert("cannot move the unlock time up");
        locker.lock(5_000e18, 120 days, true);
    }

    function testReceiveFees() public {
        vm.prank(bb8);
        locker.lock(1_000e18, 120 days);

        skip(20 days);
        _depositFees(10_000e18, 5_000e18);
        // alone in the locker, so should receive all fees

        (uint256 claimableCrv, uint256 claimableCvx) = locker.claimableFees(bb8);
        assertEq(claimableCrv, 10_000e18);
        assertEq(claimableCvx, 5_000e18);

        vm.prank(bb8);
        (uint256 claimedCrv, uint256 claimedCvx) = locker.claimFees();
        assertEq(claimedCrv, 10_000e18);
        assertEq(claimedCvx, 5_000e18);
    }

    function testTimeBoost() public {
        vm.startPrank(bb8);
        locker.lock(1_000e18, 120 days);
        uint256 expectedBalance = 1_000e18;
        assertEq(locker.balanceOf(bb8), expectedBalance);

        locker.lock(1_000e18, 240 days);
        expectedBalance += 1_500e18;
        assertEq(locker.balanceOf(bb8), expectedBalance);

        locker.lock(1_000e18, 180 days);
        expectedBalance += 1_250e18;
        assertEq(locker.balanceOf(bb8), expectedBalance);
    }

    function testUnlockSingle() public {
        vm.startPrank(bb8);
        locker.lock(1_000e18, 120 days);
        skip(120 days);
        uint256 balanceBefore = cnc.balanceOf(bb8);
        uint256 unlocked = locker.executeAvailableUnlocks();
        assertEq(unlocked, 1_000e18);
        assertEq(cnc.balanceOf(bb8) - balanceBefore, 1_000e18);
        assertEq(locker.totalLocked(), 0);
    }

    function testUnlockForSingle() public {
        vm.startPrank(bb8);
        locker.lock(1_000e18, 120 days);
        skip(120 days);
        uint256 balanceBefore = cnc.balanceOf(bb8);
        uint256 unlocked = locker.executeAvailableUnlocksFor(r2);
        assertEq(unlocked, 1_000e18);
        assertEq(cnc.balanceOf(r2), 1_000e18);
        assertEq(cnc.balanceOf(bb8), balanceBefore);
        assertEq(locker.totalLocked(), 0);
    }

    function testUnlockForMultiple() public {
        vm.startPrank(bb8);
        locker.lock(1_000e18, 120 days);
        skip(20 days);
        locker.lock(2_000e18, 160 days);
        skip(60 days);
        locker.lock(4_000e18, 120 days);
        skip(100 days);
        uint256 balanceBefore = cnc.balanceOf(bb8);
        assertEq(locker.unlockableBalance(bb8), 3_000e18);
        uint256 unlocked = locker.executeAvailableUnlocksFor(r2);
        assertEq(unlocked, 3_000e18);
        assertEq(cnc.balanceOf(r2), 3_000e18);
        assertEq(cnc.balanceOf(bb8), balanceBefore);
        assertEq(locker.totalLocked(), 4_000e18);
    }

    function testKick() public {
        vm.prank(bb8);
        locker.lock(1_000e18, 120 days);
        vm.startPrank(r2);

        vm.expectRevert("cannot kick this lock");
        locker.kick(bb8, 0);
        skip(130 days);

        // grace period
        vm.expectRevert("cannot kick this lock");
        locker.kick(bb8, 0);

        skip(18 days);
        uint256 balanceBB8Before = cnc.balanceOf(bb8);
        uint256 balanceR2Before = cnc.balanceOf(r2);
        locker.kick(bb8, 0);

        assertEq(cnc.balanceOf(bb8) - balanceBB8Before, 900e18);
        assertEq(cnc.balanceOf(r2) - balanceR2Before, 100e18);

        assertEq(locker.totalLocked(), 0);
        assertEq(locker.balanceOf(bb8), 0);
        assertEq(locker.unlockableBalance(bb8), 0);
        assertEq(locker.userLocks(bb8).length, 0);
    }

    function testAirdropBoost() public {
        bytes32[] memory hashes = new bytes32[](13);
        hashes[0] = 0x7ca1e15cf85ed4fbb5f8dd9566c910517f2e2871ff5a719c95c8c317b7af2046;
        hashes[1] = 0x64603ac91011722e440fdaa074583dbd52fc00f149a6fbbb70fd99959e933007;
        hashes[2] = 0x4f9570b883342d333b05fc60966ab1582735abdd98de9e6d9c620fd8764b31ae;
        hashes[3] = 0x2c02508e5db7a5bf4277e05a7d43dbf59bf56da6304eded9872c774549b17e20;
        hashes[4] = 0xc65d7cc1301dd598ded70be0a74f6cc41ae4654b070f396e5b9aef543586be44;
        hashes[5] = 0x8179b920aad9d9620965ceb6466824a52518bfbf1311baee0c8bfcb59c47ee4f;
        hashes[6] = 0xe969024c241f8a278fbe48d0ea6f4bd72be28095cc7b90c47020a20ef978303e;
        hashes[7] = 0xd2629e37539438ff8fc902f0b01a24e563bb806161c4e80e4162d7fc0b9fd36b;
        hashes[8] = 0xa92546f2a3b4aa6d7597394347058f6ff4399e93afd5f0f906ea55c71d1ca1e7;
        hashes[9] = 0xcf0d41bd8f1b6babd0963311fc9c5094e2c4244bb7a615993b8f08850abc4eb7;
        hashes[10] = 0x6de69d55935268c26b4f9d160bbdde8ec4f3643c0d131648c0f90cee1f274a46;
        hashes[11] = 0xb93a3fd2962a489384d088b8b65d7d5f4859a99e3b5e577c580124edef26eab9;
        hashes[12] = 0x183a9442163a3a1ffc2d6d0ac3b6932640781aaea1a1365b619d0acd2f61f1b5;
        MerkleProof.Proof memory proof = MerkleProof.Proof({nodeIndex: 47, hashes: hashes});
        address claimer = 0x6f809A9b799697b4fDD656c29deAC20ed55D330b;
        uint256 claimAmount = 1485536145937179580;
        vm.prank(claimer);
        locker.claimAirdropBoost(claimAmount, proof);
    }

    function _depositFees(uint256 crvAmount, uint256 cvxAmount) public {
        MockErc20(address(locker.crv())).mintFor(c3po, crvAmount);
        MockErc20(address(locker.cvx())).mintFor(c3po, cvxAmount);

        vm.startPrank(c3po);
        locker.crv().approve(address(locker), crvAmount);
        locker.cvx().approve(address(locker), cvxAmount);
        locker.receiveFees(crvAmount, cvxAmount);
        vm.stopPrank();
    }
}
