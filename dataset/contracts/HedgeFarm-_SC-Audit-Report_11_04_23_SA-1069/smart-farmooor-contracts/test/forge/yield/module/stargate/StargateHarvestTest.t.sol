// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StargateBaseTest.t.sol";
import "../../../../../contracts/yield/interface/stargate/IPool.sol";

contract StargateHarvestTest is StargateBaseTest {

    function testCanHarvest() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);
        _harvest(address(smartFarmooor), SMALL_AMOUNT, address(smartFarmooor));
        
        assertApproxEqAbs(stargateYieldModule.getBalance(), SMALL_AMOUNT, 1);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(stargateYieldModule)), 0);
        assertGt(IERC20(stargateYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
    }

    function testOnlySmartFarmooorCanHarvest() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);
        _harvest(address(smartFarmooor), SMALL_AMOUNT, address(smartFarmooor));
        _moveBlock(1000);
        
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.harvest(address(smartFarmooor));
    }

    function testOwnerCannotHarvest() public {
        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.harvest(address(smartFarmooor));
    }

    function testManagerCannotHarvest() public {
        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.harvest(address(smartFarmooor));
    }

    function testHarvestEmitEvent() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);

        vm.startPrank(address(smartFarmooor));
        vm.expectEmit(false, false, false, false);
        emit Harvest(stargateYieldModule.baseToken(), 0);
        stargateYieldModule.harvest(address(smartFarmooor));
        vm.stopPrank();
    }


    function testHarvestRevertOnLpTokenValueDecrease() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _moveBlock(1000);

         // decrease LP token liquidity in Stargate pool - it will decrease LP token value
         vm.mockCall(
            stargateYieldModule.pool(),
            abi.encodeWithSelector(IPool.totalLiquidity.selector),
            abi.encode(uint256(1000))
        );

        vm.startPrank(address(smartFarmooor));
        vm.expectRevert("Stargate: currentPricePerShare smaller than last one");
        stargateYieldModule.harvest(address(smartFarmooor));
        vm.stopPrank();
    }
}
