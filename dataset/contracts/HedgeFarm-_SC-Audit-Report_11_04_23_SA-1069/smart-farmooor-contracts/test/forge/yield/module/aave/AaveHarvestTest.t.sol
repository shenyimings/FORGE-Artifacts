// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AaveBaseTest.t.sol";

contract AaveHarvestTest is AaveBaseTest {

    function testCanHarvest() public {
        uint256 lastPricePerShare = aaveYieldModule.lastPricePerShare();
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(10000);
        _harvest(address(smartFarmooor), address(smartFarmooor));
        uint256 currentPricePerShare = aaveYieldModule.lastPricePerShare();
        
        assertApproxEqAbs(aaveYieldModule.getBalance(), SMALL_AMOUNT, 1);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(address(aaveYieldModule)), 0);
        assertGt(IERC20(aaveYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        // We can only supply SAVAX on aave -> the pps never changes
        if (BASE_TOKEN == SAVAX) {
            assertEq(currentPricePerShare, lastPricePerShare);
        } else {
            assertGt(currentPricePerShare, lastPricePerShare);
        }
    }

    function testOnlySmartFarmooorCanHarvest() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);
        _harvest(address(smartFarmooor), address(smartFarmooor));
        _moveBlock(1000);
        
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.harvest(address(smartFarmooor));
    }

    function testOwnerCannotHarvest() public {
        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.harvest(address(smartFarmooor));
    }

    function testManagerCannotHarvest() public {
        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.harvest(address(smartFarmooor));
    }

    function testHarvestEmitEvent() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);

        vm.startPrank(address(smartFarmooor));
        vm.expectEmit(false, false, false, false);
        emit Harvest(aaveYieldModule.baseToken(), 0);
        aaveYieldModule.harvest(address(smartFarmooor));
        vm.stopPrank();
    }

    function testCanHarvestEvenIfLastPricePerShareEqualCurrentPricePerShare() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _harvest(address(smartFarmooor), OWNER);
        // The second harvest should never revert because of : "Aave: module not profitable"
        _harvest(address(smartFarmooor), OWNER);
    }

    function testRevertIfModuleIsNotProfitable() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.mockCall(
            aaveYieldModule.pool(),
            abi.encodeWithSelector(IPoolAave.getReserveNormalizedIncome.selector),
            abi.encode(1)
        );

        vm.expectRevert("Aave: module not profitable");
        _harvest(address(smartFarmooor), OWNER);
    }
}