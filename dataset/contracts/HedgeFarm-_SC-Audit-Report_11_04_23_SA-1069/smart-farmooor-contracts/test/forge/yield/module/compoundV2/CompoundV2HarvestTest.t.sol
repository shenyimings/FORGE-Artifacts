// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompoundV2BaseTest.t.sol";

contract CompoundV2HarvestTest is CompoundV2BaseTest {

    function testCanHarvest() public {
        uint256 lastPricePerShare = yieldModule.lastPricePerShare();
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);
        _harvest(address(smartFarmooor), address(smartFarmooor));
        uint256 currentPricePerShare = yieldModule.lastPricePerShare();

        assertApproxEqAbs(yieldModule.getBalance(), SMALL_AMOUNT, PRECISION);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(yieldModule)), 0);
        assertGt(IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertGt(currentPricePerShare, lastPricePerShare);
    }

    function testOnlySmartFarmooorCanHarvest() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);
        _harvest(address(smartFarmooor), address(smartFarmooor));
        _moveBlock(1000);

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.harvest(address(smartFarmooor));
    }

    function testOwnerCannotHarvest() public {
        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.harvest(address(smartFarmooor));
    }

    function testManagerCannotHarvest() public {
        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.harvest(address(smartFarmooor));
    }

    function testHarvestEmitEvent() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);

        vm.startPrank(address(smartFarmooor));
        vm.expectEmit(false, false, false, false);
        emit Harvest(yieldModule.baseToken(), 0);
        yieldModule.harvest(address(smartFarmooor));
        vm.stopPrank();
    }

    function testCanHarvestEvenIfLastPricePerShareEqualCurrentPricePerShare() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _harvest(address(smartFarmooor), RANDOM_ADDRESS);
        // The second harvest should never revert because of : "CompoundV2: module not profitable"
        _harvest(address(smartFarmooor), RANDOM_ADDRESS);
    }

    function testRevertIfModuleIsNotProfitable() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.mockCall(
            yieldModule.cToken(),
            abi.encodeWithSelector(CTokenInterface.exchangeRateCurrent.selector),
            abi.encode(1)
        );

        vm.expectRevert("CompoundV2: module not profitable");
        _harvest(address(smartFarmooor), RANDOM_ADDRESS);
    }

    function testAvaxRewardAreSwappedOrStaysOnTheModuleVerySmallAmount() public {
        _deposit(address(smartFarmooor), VERY_SMALL_AMOUNT);
        _moveBlock(1);

        //nothing left on module and Dex when single deposit is made
        _harvest(address(smartFarmooor), address(smartFarmooor));

        assertEq(address(dex).balance, 0);
        assertEq(address(yieldModule).balance, 0);
        assertEq(address(smartFarmooor).balance, 0);
        IERC20(yieldModule.baseToken()).balanceOf(address(yieldModule));
        IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor));
    }

    function testAvaxRewardAreSwappedOrStaysOnTheModuleSmallAmount() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1);
        _harvest(address(smartFarmooor), address(smartFarmooor));
        assertEq(address(dex).balance, 0);
        assertTrue(address(yieldModule).balance > 0 || IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor)) > 0);
    }

    function testAvaxRewardAreSwappedOrStaysOnTheModuleBigAmount() public {
        _deposit(address(smartFarmooor), BIG_AMOUNT);
        _moveBlock(1);
        _harvest(address(smartFarmooor), address(smartFarmooor));
        assertEq(address(dex).balance, 0);
        assertTrue(address(yieldModule).balance > 0 || IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor)) > 0);
    }
}
