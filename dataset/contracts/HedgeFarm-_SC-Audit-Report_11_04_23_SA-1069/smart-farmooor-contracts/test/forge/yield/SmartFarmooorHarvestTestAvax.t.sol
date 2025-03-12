// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../script/Deployer.s.sol";
import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorHarvestTestAvax is SmartFarmooorBasicTestHelperAvax {
    using SafeERC20 for IERC20;

    function testHarvestGrowsTheIouValue() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        uint256 lastUpdatedPricePerShareBefore = smartFarmooor
            .lastUpdatedPricePerShare();
        uint256 pricePerShareBefore = smartFarmooor.pricePerShare();
        _moveBlock(1000);
        if (BASE_TOKEN != SAVAX) {
            // SAVAX cannot be borrowed so their is no LP interest
            assertGt(
                smartFarmooor.lastUpdatedPricePerShare(),
                lastUpdatedPricePerShareBefore
            );
            assertLt(
                smartFarmooor.lastUpdatedPricePerShare(),
                smartFarmooor.pricePerShare()
            );
        }
        smartFarmooor.harvest();

        uint256 lastUpdatedPricePerShareAfter = smartFarmooor
            .lastUpdatedPricePerShare();
        uint256 pricePerShareAfter = smartFarmooor.pricePerShare();
        assertGt(pricePerShareAfter, pricePerShareBefore);
        assertGt(lastUpdatedPricePerShareAfter, lastUpdatedPricePerShareBefore);
    }

    function testShouldHarvest0IfSupplyIsNull() public {
        uint256 totalSupply = smartFarmooor.totalSupply();
        assertEq(totalSupply, 0);

        uint256 profit = smartFarmooor.harvest();
        assertEq(profit, 0);
    }

    function testShouldSendPerfFeeToFeeManager() public {
        vm.prank(address(timelock));
        smartFarmooor.setPerformanceFee(10 * 100);

        testHarvestGrowsTheIouValue();

        assertGt(IERC20(BASE_TOKEN).balanceOf(smartFarmooor.feeManager()), 0);
    }

    function testShouldReturnNetProfitOnly() public {
        vm.prank(address(timelock));
        smartFarmooor.setPerformanceFee(0);
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _moveBlock(10000000);
        //0% perf fee
        smartFarmooor.harvest();
        assertEq(IERC20(BASE_TOKEN).balanceOf(SM_FEE_MANAGER), 0);
        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));
        assertEq(smartFarmooor.getModulesBalance(), 0);
        assertGt(IERC20(BASE_TOKEN).balanceOf(ALICE), DEPOSIT_AMOUNT);

        vm.prank(address(timelock));
        uint16 perfFee = MAX_BPS / 10;
        //10% perf fee
        smartFarmooor.setPerformanceFee(perfFee);

        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _moveBlock(10000000);
        uint256 netProfit = smartFarmooor.harvest(); //90%
        uint256 fee = IERC20(BASE_TOKEN).balanceOf(SM_FEE_MANAGER);
        assertGt(IERC20(BASE_TOKEN).balanceOf(SM_FEE_MANAGER), 0);
        assertApproxEqAbs(
            netProfit,
            (fee * MAX_BPS) / perfFee - fee,
            smartFarmooor.numberOfModules() * PRECISION
        );
    }

    function testShouldCompoundProfits() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _moveBlock(10000000);
        uint256 netProfit = smartFarmooor.harvest(); //90%
        assertApproxEqAbs(smartFarmooor.getModulesBalance(), DEPOSIT_AMOUNT + netProfit, PRECISION);
    }
}
