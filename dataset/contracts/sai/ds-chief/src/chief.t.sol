/*
   Copyright 2017 DappHub, LLC

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
pragma solidity ^0.4.17;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./chief.sol";


contract ChiefUser {
    DSChief chief;

    function ChiefUser(DSChief chief_) public {
        chief = chief_;
    }

    function doTransferFrom(DSToken token, address from, address to,
                            uint amount)
        public
        returns (bool)
    {
        return token.transferFrom(from, to, amount);
    }

    function doTransfer(DSToken token, address to, uint amount)
        public
        returns (bool)
    {
        return token.transfer(to, amount);
    }

    function doApprove(DSToken token, address recipient, uint amount)
        public
        returns (bool)
    {
        return token.approve(recipient, amount);
    }

    function doAllowance(DSToken token, address owner, address spender)
        public
        constant returns (uint)
    {
        return token.allowance(owner, spender);
    }

    function doEtch(address[] guys) public returns (bytes32) {
        return chief.etch(guys);
    }

    function doVote(address[] guys) public returns (bytes32) {
        return chief.vote(guys);
    }

    function doVote(address[] guys, address lift_whom) public returns (bytes32) {
        return chief.vote(guys, lift_whom);
    }

    function doVote(bytes32 id) public {
        chief.vote(id);
    }

    function doVote(bytes32 id, address lift_whom) public {
        chief.vote(id, lift_whom);
    }

    function doLift(address to_lift) public {
        chief.lift(to_lift);
    }

    function doLock(uint amt) public {
        chief.lock(amt);
    }

    function doFree(uint amt) public {
        chief.free(amt);
    }
}

contract DSChiefTest is DSTest {
    uint256 constant electionSize = 3;

    // c prefix: candidate
    address constant c1 = 0x1;
    address constant c2 = 0x2;
    address constant c3 = 0x3;
    address constant c4 = 0x4;
    address constant c5 = 0x5;
    address constant c6 = 0x6;
    address constant c7 = 0x7;
    address constant c8 = 0x8;
    address constant c9 = 0x9;
    uint256 constant initialBalance = 1000 ether;
    uint256 constant uLargeInitialBalance = initialBalance / 3;
    uint256 constant uMediumInitialBalance = initialBalance / 4;
    uint256 constant uSmallInitialBalance = initialBalance / 5;

    DSChief chief;
    DSToken gov;
    DSToken iou;

    // u prefix: user
    ChiefUser uLarge;
    ChiefUser uMedium;
    ChiefUser uSmall;

    function setUp() public {
        gov = new DSToken("GOV");
        gov.mint(initialBalance);

        iou = new DSToken("IOU");

        chief = new DSChief(gov, iou, electionSize);
        iou.setOwner(chief);

        uLarge = new ChiefUser(chief);
        uMedium = new ChiefUser(chief);
        uSmall = new ChiefUser(chief);

        assert(initialBalance > uLargeInitialBalance + uMediumInitialBalance +
               uSmallInitialBalance);
        assert(uLargeInitialBalance < uMediumInitialBalance + uSmallInitialBalance);

        gov.transfer(uLarge, uLargeInitialBalance);
        gov.transfer(uMedium, uMediumInitialBalance);
        gov.transfer(uSmall, uSmallInitialBalance);
    }

    function test_basic_sanity() public pure {
        assert(true);
    }

    function testFail_basic_sanity() public pure {
        assert(false);
    }

    function test_etch_returns_same_id_for_same_sets() public {
        var candidates = new address[](3);
        candidates[0] = c1;
        candidates[1] = c2;
        candidates[2] = c3;

        var id = uSmall.doEtch(candidates);
        assert(id != 0x0);
        assertEq32(id, uMedium.doEtch(candidates));
    }

    function test_size_zero_slate() public {
        var candidates = new address[](0);
        var id = uSmall.doEtch(candidates);
        uSmall.doVote(id);
    }
    function test_size_one_slate() public {
        var candidates = new address[](1);
        candidates[0] = c1;
        var id = uSmall.doEtch(candidates);
        uSmall.doVote(id);
    }

    function testFail_etch_requires_ordered_sets() public {
        var candidates = new address[](3);
        candidates[0] = c2;
        candidates[1] = c1;
        candidates[2] = c3;

        uSmall.doEtch(candidates);
    }

    function test_lock_debits_user() public {
        assert(gov.balanceOf(uLarge) == uLargeInitialBalance);

        var lockedAmt = uLargeInitialBalance / 10;
        uLarge.doApprove(gov, chief, lockedAmt);
        uLarge.doLock(lockedAmt);

        assert(gov.balanceOf(uLarge) == uLargeInitialBalance -
               lockedAmt);
    }

    function test_changing_weight_after_voting() public {
        var uLargeLockedAmt = uLargeInitialBalance / 2;
        uLarge.doApprove(iou, chief, uLargeLockedAmt);
        uLarge.doApprove(gov, chief, uLargeLockedAmt);
        uLarge.doLock(uLargeLockedAmt);

        var uLargeSlate = new address[](1);
        uLargeSlate[0] = c1;
        uLarge.doVote(uLargeSlate);

        assert(chief.approvals(c1) == uLargeLockedAmt);

        // Changing weight should update the weight of our candidate.
        uLarge.doFree(uLargeLockedAmt);
        assert(chief.approvals(c1) == 0);

        uLargeLockedAmt = uLargeInitialBalance / 4;
        uLarge.doApprove(gov, chief, uLargeLockedAmt);
        uLarge.doLock(uLargeLockedAmt);

        assert(chief.approvals(c1) == uLargeLockedAmt);
    }

    function test_voting_and_reordering() public {
        assert(gov.balanceOf(uLarge) == uLargeInitialBalance);

        initial_vote();

        // Upset the order.
        var uLargeLockedAmt = uLargeInitialBalance;
        uLarge.doApprove(gov, chief, uLargeLockedAmt);
        uLarge.doLock(uLargeLockedAmt);

        var uLargeSlate = new address[](1);
        uLargeSlate[0] = c3;
        uLarge.doVote(uLargeSlate);
    }

    function testFail_lift_while_out_of_order() public {
        initial_vote();

        // Upset the order.
        uSmall.doApprove(gov, chief, uSmallInitialBalance);
        uSmall.doLock(uSmallInitialBalance);

        var uSmallSlate = new address[](1);
        uSmallSlate[0] = c3;
        uSmall.doVote(uSmallSlate);

        uMedium.doFree(uMediumInitialBalance);

        chief.lift(c3);
    }

    function test_lift_half_approvals() public {
        initial_vote();

        // Upset the order.
        uSmall.doApprove(gov, chief, uSmallInitialBalance);
        uSmall.doLock(uSmallInitialBalance);

        var uSmallSlate = new address[](1);
        uSmallSlate[0] = c3;
        uSmall.doVote(uSmallSlate);

        uMedium.doApprove(iou, chief, uMediumInitialBalance);
        uMedium.doFree(uMediumInitialBalance);

        chief.lift(c3);

        assert(!chief.isUserRoot(c1));
        assert(!chief.isUserRoot(c2));
        assert(chief.isUserRoot(c3));
    }

    function testFail_voting_and_reordering_without_weight() public {
        assert(gov.balanceOf(uLarge) == uLargeInitialBalance);

        initial_vote();

        // Vote without weight.
        var uLargeSlate = new address[](1);
        uLargeSlate[0] = c3;
        uLarge.doVote(uLargeSlate);

        // Attempt to update the elected set.
        chief.lift(c3);
    }

    function test_voting_by_slate_id() public {
        assert(gov.balanceOf(uLarge) == uLargeInitialBalance);

        var slateID = initial_vote();

        // Upset the order.
        uLarge.doApprove(gov, chief, uLargeInitialBalance);
        uLarge.doLock(uLargeInitialBalance);

        var uLargeSlate = new address[](1);
        uLargeSlate[0] = c4;
        uLarge.doVote(uLargeSlate);

        // Update the elected set to reflect the new order.
        chief.lift(c4);

        // Now restore the old order using a slate ID.
        uSmall.doApprove(gov, chief, uSmallInitialBalance);
        uSmall.doLock(uSmallInitialBalance);
        uSmall.doVote(slateID);

        // Update the elected set to reflect the restored order.
        chief.lift(c1);
    }

    function initial_vote() internal returns (bytes32 slateID) {
        var uMediumLockedAmt = uMediumInitialBalance;
        uMedium.doApprove(gov, chief, uMediumLockedAmt);
        uMedium.doLock(uMediumLockedAmt);

        var uMediumSlate = new address[](3);
        uMediumSlate[0] = c1;
        uMediumSlate[1] = c2;
        uMediumSlate[2] = c3;
        slateID = uMedium.doVote(uMediumSlate);

        // Lift the chief.
        chief.lift(c1);
    }
}
