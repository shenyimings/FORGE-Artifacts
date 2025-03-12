// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompoundV2BaseTest.t.sol";

contract CompoundV2WithdrawTest is CompoundV2BaseTest {

    function testCanWithdraw() public {
        uint256 shareFraction = SMALL_AMOUNT * 1e18 / BIG_AMOUNT;
        _deposit(address(smartFarmooor), BIG_AMOUNT);
        _withdraw(address(smartFarmooor), shareFraction, ALICE);

        assertApproxEqAbs(yieldModule.getBalance(), BIG_AMOUNT - SMALL_AMOUNT, PRECISION);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(yieldModule)), 0);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertApproxEqAbs(IERC20(yieldModule.baseToken()).balanceOf(ALICE), SMALL_AMOUNT, PRECISION);
    }

    function testCanWithdrawNative() public {
        // Deposit
        BASE_TOKEN = WAVAX;
        BENQI_TOKEN = BENQI_AVAX;
        PRECISION = 10**9;
        deployBenqiYieldModule(address(smartFarmooor), address(dex));
        yieldModule = benqiYieldModule;

        deal(WAVAX, address(smartFarmooor), BIG_AMOUNT);
        vm.startPrank(address(smartFarmooor));
        IERC20(yieldModule.baseToken()).approve(address(yieldModule), BIG_AMOUNT);
        yieldModule.deposit(BIG_AMOUNT);
        vm.stopPrank();

        // Withdraw
        uint256 shareFraction = SMALL_AMOUNT * 1e18 / BIG_AMOUNT;
        _withdraw(address(smartFarmooor), shareFraction, ALICE);

        assertApproxEqAbs(yieldModule.getBalance(), BIG_AMOUNT - SMALL_AMOUNT, PRECISION);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(yieldModule)), 0);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertApproxEqAbs(IERC20(yieldModule.baseToken()).balanceOf(ALICE), SMALL_AMOUNT, PRECISION);
    }

    function testCanWithdrawAll() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _withdraw(address(smartFarmooor), ALL_SHARE_AS_FRACTION, ALICE);
        
        assertEq(yieldModule.getBalance(), 0);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(yieldModule)), 0);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertApproxEqAbs(IERC20(yieldModule.baseToken()).balanceOf(ALICE), SMALL_AMOUNT, PRECISION);
    }

    function testOnlySmartFarmooorCanWithdraw() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _withdraw(address(smartFarmooor), ALL_SHARE_AS_FRACTION, ALICE);

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.withdraw(ALL_SHARE_AS_FRACTION, ALICE);
    }

    function testOwnerCannotWithdraw() public {
        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.withdraw(ALL_SHARE_AS_FRACTION, ALICE);
    }

    function testManagerCannotWithdraw() public {
        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.withdraw(ALL_SHARE_AS_FRACTION, ALICE);
    }

    function testWithdrawShareFractionCannotBeZero() public {
        vm.prank(address(smartFarmooor));
        vm.expectRevert("CompoundV2: shareFraction cannot be zero");
        yieldModule.withdraw(0, ALICE);
    }

    function testMsgValueMustBeZeroToWithdraw() public {
        deal(address(smartFarmooor), 1e17);
        vm.prank(address(smartFarmooor));
        vm.expectRevert("CompoundV2: msg.value must be zero");
        yieldModule.withdraw{value : 1e17}(ALL_SHARE_AS_FRACTION, ALICE);
    }

    function testDepositEmitEvent() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.startPrank(address(smartFarmooor));
        vm.expectEmit(false, false, false, false);
        emit Withdraw(yieldModule.baseToken(), SMALL_AMOUNT);
        yieldModule.withdraw(ALL_SHARE_AS_FRACTION, ALICE);
        vm.stopPrank();
    }

    function testShouldFailOnLpTokenRescueWithdrawal() public {
        address lpToken = yieldModule.cToken();
        vm.startPrank(OWNER);
        vm.expectRevert(bytes("BaseModule: can't pull out lp tokens"));
        yieldModule.rescueToken(lpToken);
        vm.stopPrank();
    }

    function testShouldAllowTokenRescueWithdrawal() public {
        deal(yieldModule.baseToken(), address(yieldModule), SMALL_AMOUNT);
        _moveBlock(1);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(OWNER), 0);
        vm.startPrank(OWNER);
        yieldModule.rescueToken(yieldModule.baseToken());
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(OWNER), SMALL_AMOUNT);
        vm.stopPrank();
    }
}