// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../script/Deployer.s.sol";
import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorPanicTestAvax is SmartFarmooorBasicTestHelperAvax {
    using SafeERC20 for IERC20;

    function testPanicEmptiesModules() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module, uint allocation) = smartFarmooor.yieldOptions(i);
            assertApproxEqAbs(module.getBalance(), DEPOSIT_AMOUNT * allocation / smartFarmooor.MAX_BPS(), PRECISION);
        }

        _moveBlock(1000);
        smartFarmooor.harvest();

        _moveBlock(1);

        vm.prank(address(timelock));
        smartFarmooor.panic();

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module,) = smartFarmooor.yieldOptions(i);
            assertApproxEqAbs(module.getBalance(), 0, smartFarmooor.numberOfModules() * PRECISION);
        }
    }

    function testPanicShouldSendFundsToManager() public {
        testPanicEmptiesModules();

        //Gt because harvest is counted
        assertGt(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), DEPOSIT_AMOUNT);
    }

    function testBalanceSnapshotShouldBeEqualToLocalBalanceAfterPanic() public {
        testPanicEmptiesModules();

        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), smartFarmooor.balanceSnapshot());
    }

    function testRandomAddressCanNotPanic() public {
        vm.prank(RANDOM_ADDRESS);
        //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4 and PANICOOOR_ROLE == 0xa342a293161a8d2ea19a8f810f41e62de0d97b54d0eddb3a7b5e2abcc379c931
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0xa342a293161a8d2ea19a8f810f41e62de0d97b54d0eddb3a7b5e2abcc379c931'));
        smartFarmooor.panic();
    }

    function testOwnerCanPanic() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        vm.prank(address(timelock));
        smartFarmooor.panic();
    }

    function testManagerCanPanic() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        vm.prank(MANAGER);
        smartFarmooor.panic();
    }

    function testPanicShouldPause() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.prank(address(timelock));
        smartFarmooor.panic();

        assertEq(smartFarmooor.paused(), true);
    }

    function testFinishPanicShouldUnpause() public {
        testPanicShouldPause();

        vm.prank(address(timelock));
        smartFarmooor.finishPanic();

        assertEq(smartFarmooor.paused(), false);
    }

    function testFinishPanicShouldResetBalanceSnapshot() public {
        testPanicShouldPause();

        vm.prank(address(timelock));
        smartFarmooor.finishPanic();

        assertEq(smartFarmooor.balanceSnapshot(), 0);
    }

    function testManagerCanFinishPanicNotRandomAddress() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.prank(MANAGER);
        smartFarmooor.panic();

        vm.prank(RANDOM_ADDRESS);
        //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08'));
        smartFarmooor.finishPanic();

        vm.prank(MANAGER);
        smartFarmooor.finishPanic();
    }

    function testOwnerCanFinishPanicNotRandomAddress() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.prank(address(timelock));
        smartFarmooor.panic();

        vm.prank(RANDOM_ADDRESS);
        //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08'));
        smartFarmooor.finishPanic();

        vm.prank(address(timelock));
        smartFarmooor.finishPanic();
    }

    function testCanOnlyFinishPanicIfAllFundsAreBackInTheSmartFarmooor() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.prank(address(timelock));
        smartFarmooor.panic();

        uint256 smartFarmooorBalance = IERC20(BASE_TOKEN).balanceOf(address(smartFarmooor));
        deal(BASE_TOKEN, address(smartFarmooor), smartFarmooorBalance / 2);

        vm.prank(address(timelock));
        vm.expectRevert(bytes("SmartFarmooor: funds still pending"));
        smartFarmooor.finishPanic();

        deal(BASE_TOKEN, address(smartFarmooor), smartFarmooorBalance);

        vm.prank(address(timelock));
        smartFarmooor.finishPanic();
    }

    function testFinishPanicAcceptASmallDifferenceBetweenTheLocalBalanceAndTheBalanceSnapshot() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.prank(address(timelock));
        smartFarmooor.panic();

        uint256 smartFarmooorBalance = IERC20(BASE_TOKEN).balanceOf(address(smartFarmooor));
        deal(BASE_TOKEN, address(smartFarmooor), smartFarmooorBalance * (MAX_BPS - 10) / MAX_BPS - 1);

        vm.prank(address(timelock));
        vm.expectRevert(bytes("SmartFarmooor: funds still pending"));
        smartFarmooor.finishPanic();

        deal(BASE_TOKEN, address(smartFarmooor), smartFarmooorBalance * (MAX_BPS - 10) / MAX_BPS);

        vm.prank(address(timelock));
        smartFarmooor.finishPanic();
        assertEq(smartFarmooor.paused(), false);
    }

    function testShouldDepositOnFinishPanic() public {
        testPanicEmptiesModules();

        vm.prank(address(timelock));
        smartFarmooor.finishPanic();

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module, uint allocation) = smartFarmooor.yieldOptions(i);
            assertGt(module.getBalance(), DEPOSIT_AMOUNT * allocation / smartFarmooor.MAX_BPS());
        }
        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), 0);
    }

    function testShouldDepositEntireBaseTokenBalance() public {
        testShouldDepositOnFinishPanic();

        //deposit extra baseToken on SmartFarmooor
        deal(smartFarmooor.baseToken(), address(smartFarmooor), DEPOSIT_AMOUNT);

        _moveBlock(10);

        vm.prank(address(timelock));
        smartFarmooor.panic();
        assertGt(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), DEPOSIT_AMOUNT * 2);

        vm.prank(address(timelock));
        smartFarmooor.finishPanic();

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module, uint allocation) = smartFarmooor.yieldOptions(i);
            assertGt(module.getBalance(), DEPOSIT_AMOUNT * allocation / smartFarmooor.MAX_BPS());
        }
        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), 0);
    }

    function testPanicShouldSetPricePerShareToZero() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.prank(address(timelock));
        smartFarmooor.panic();

        uint ppsAfter = smartFarmooor.pricePerShare();
        assertEq(ppsAfter, 0);
    }

    function testPanicFinishPanicShouldNotChangePricePerShare() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        uint ppsBefore = smartFarmooor.pricePerShare();

        vm.startPrank(address(timelock));
        smartFarmooor.panic();
        _moveBlock(1);
        smartFarmooor.finishPanic();

        uint ppsAfter = smartFarmooor.pricePerShare();
        assertApproxEqAbs(ppsBefore, ppsAfter, IOU_DECIMALS / PRECISION);
    }

    function testPanicWithMultipleModules() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        depositHelper(BOB, DEPOSIT_AMOUNT);

        _moveBlock(10000);

        vm.prank(address(timelock));
        smartFarmooor.panic();
        assertGt(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), DEPOSIT_AMOUNT * 2);
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module,) = smartFarmooor.yieldOptions(i);
            // In aave there only reward APY so the balance does not increase
            assertEq(module.getBalance(), 0);
        }
    }

    function testShouldHaveMaxBPSAllocation() public {
        testPanicShouldPause();

        vm.startPrank(address(timelock));

        //remove a module with an allocation != 0
        (, uint allocation) = smartFarmooor.yieldOptions(0);
        assertGt(allocation, 0);
        smartFarmooor.removeModule(0);

        vm.expectRevert(bytes("SmartFarmooor: total allocation is wrong"));
        smartFarmooor.finishPanic();
        vm.stopPrank();
    }

    function testModuleShouldNotHaveAllocationSetToZero() public {
        testPanicShouldPause();

        vm.startPrank(address(timelock));

        (IYieldModule module, uint allocation) = smartFarmooor.yieldOptions(0);
        smartFarmooor.addModule(module);

        vm.expectRevert(bytes("SmartFarmooor: Min allocation too low"));
        smartFarmooor.finishPanic();

        uint numberOfModules = smartFarmooor.numberOfModules();
        uint[] memory allocations = new uint[](numberOfModules);
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module,) = smartFarmooor.yieldOptions(i);
            // In aave there only reward APY so the balance does not increase
            allocations[i] = smartFarmooor.MAX_BPS() / numberOfModules;
        }

        if (numberOfModules == 3)
            allocations[numberOfModules - 1]++;

        smartFarmooor.setModuleAllocation(allocations);
        smartFarmooor.finishPanic();

        assertEq(smartFarmooor.paused(), false);
        vm.stopPrank();
    }
}
