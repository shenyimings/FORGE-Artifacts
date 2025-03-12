 // SPDX-License-Identifier: MIT
 pragma solidity ^0.8.0;

 import "./SmartFarmooorBasicTestHelperAvax.t.sol";

 contract SmartFarmooorKeeperTest is SmartFarmooorBasicTestHelperAvax {

    bytes public HARVEST_PROFIT_BYTES = bytes("HARVEST_PROFIT");

     function testCheckUpkeepHarvestProfit() public {
        (bool upkeepNeeded, bytes memory performData) = smartFarmooor.checkUpkeep(HARVEST_PROFIT_BYTES);
        assertTrue(upkeepNeeded);
        assertEq(keccak256(performData), keccak256(HARVEST_PROFIT_BYTES));
    }

    function testCheckUpkeepUnknownTaskReturnFalseAndEmptyPerformData() public {
        (bool upkeepNeeded, bytes memory performData) = smartFarmooor.checkUpkeep(bytes("RANDOM_TASK"));
        assertTrue(!upkeepNeeded);
        assertEq(keccak256(performData), keccak256(""));
    }

    function testPerformUpkeepHarvestProfit() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        _moveBlock(100000000);

        uint256 ppsBefore = smartFarmooor.pricePerShare();
        smartFarmooor.performUpkeep(HARVEST_PROFIT_BYTES);
        uint256 ppsAfter = smartFarmooor.pricePerShare();
        assertGt(ppsAfter, ppsBefore);
    }

    function testPerformUpkeepHarvestProfitFailWhenProfitAreLowerThanHarvestThreshold() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.expectRevert("SmartFarmooor: not enough to harvest");
        smartFarmooor.performUpkeep(HARVEST_PROFIT_BYTES);
    }

    function testPerformUpkeepUnknownTaskRevert() public {
        vm.expectRevert(bytes("Unknown task"));
        smartFarmooor.performUpkeep(bytes("RANDOM_TASK"));
    }
 }