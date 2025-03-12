// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicPoolBaseTest.sol";
import "../interfaces/vendor/IBooster.sol";

contract RewardsHandlerTest is ConicPoolBaseTest {
    IConicPool public conicPool;
    IERC20Metadata public underlying;
    uint256 public decimals;

    function setUp() public override {
        super.setUp();
        underlying = IERC20Metadata(Tokens.USDC);
        decimals = underlying.decimals();
        setTokenBalance(bb8, address(underlying), 100_000 * 10 ** decimals);
        conicPool = _createConicPool(
            controller,
            rewardsHandler,
            locker,
            address(underlying),
            "Conic DAI",
            "cncDAI",
            false
        );

        conicPool.addPool(CurvePools.FRAX_3CRV);
        conicPool.addPool(CurvePools.TRI_POOL);

        controller.setAllowedMultipleDepositsWithdraws(bb8, true);

        IConicPool.PoolWeight[] memory weights = new IConicPool.PoolWeight[](2);
        weights[0] = IConicPool.PoolWeight(CurvePools.FRAX_3CRV, 0.6e18);
        weights[1] = IConicPool.PoolWeight(CurvePools.TRI_POOL, 0.4e18);
        _setWeights(address(conicPool), weights);

        vm.startPrank(bb8);
        underlying.approve(address(conicPool), 100_000 * 10 ** decimals);

        conicPool.deposit(10_000 * 10 ** decimals, 1);
        vm.stopPrank();

        skip(14 days);

        IConicPool.PoolWeight[] memory newWeights = new IConicPool.PoolWeight[](2);
        newWeights[0] = IConicPool.PoolWeight(CurvePools.FRAX_3CRV, 0.8e18);
        newWeights[1] = IConicPool.PoolWeight(CurvePools.TRI_POOL, 0.2e18);
        _setWeights(address(conicPool), newWeights);

        skip(1 days);

        assertTrue(conicPool.rebalancingRewardActive());
    }

    function testNormalRebalance() public {
        uint256 deviationBefore = conicPool.computeTotalDeviation();
        uint256 cncBalanceBefore = IERC20(controller.cncToken()).balanceOf(bb8);
        uint256 depositAmount = conicPool.computeTotalDeviation() / 2;

        vm.startPrank(bb8);
        uint256 lpBalance = conicPool.deposit(depositAmount, 1, false);
        conicPool.withdraw(lpBalance, 1);
        vm.stopPrank();

        assertLt(conicPool.computeTotalDeviation(), deviationBefore);
        uint256 cncBalanceAfter = IERC20(controller.cncToken()).balanceOf(bb8);
        assertGt(cncBalanceAfter, cncBalanceBefore);
        assertApproxEqRel(cncBalanceAfter - cncBalanceBefore, 1.5e18, 0.01e18);
    }

    function testRewardHandlerRebalance() public {
        uint256 deviationBefore = conicPool.computeTotalDeviation();
        uint256 cncBalanceBefore = IERC20(controller.cncToken()).balanceOf(bb8);
        uint256 underlyingBalanceBefore = underlying.balanceOf(bb8);
        uint256 depositAmount = conicPool.computeTotalDeviation() / 2;

        vm.startPrank(bb8);
        underlying.approve(address(rewardsHandler), depositAmount);

        vm.expectRevert("insufficient CNC received");
        rewardsHandler.rebalance(
            address(conicPool),
            depositAmount,
            (depositAmount * 9) / 10,
            10e18
        );

        vm.expectRevert("insufficient underlying received");
        rewardsHandler.rebalance(address(conicPool), depositAmount, depositAmount, 7.5e18);

        (uint256 underlyingReceived, uint256 cncReceived) = rewardsHandler.rebalance(
            address(conicPool),
            depositAmount,
            (depositAmount * 9) / 10,
            7.5e18
        );
        vm.stopPrank();

        assertGt(underlyingReceived, 0);
        uint256 balanceAfterDeposit = underlyingBalanceBefore - depositAmount;
        assertEq(underlyingReceived, underlying.balanceOf(bb8) - balanceAfterDeposit);
        assertLt(conicPool.computeTotalDeviation(), deviationBefore);
        uint256 cncBalanceAfter = IERC20(controller.cncToken()).balanceOf(bb8);
        assertGt(cncBalanceAfter, cncBalanceBefore);
        assertEq(cncReceived, cncBalanceAfter - cncBalanceBefore);
        assertApproxEqRel(cncBalanceAfter - cncBalanceBefore, 7.52e18, 0.01e18);
    }

    function testReceivesNoCncWhenBalanced() public {
        vm.startPrank(bb8);
        uint256 depositAmount = conicPool.computeTotalDeviation() / 2;
        uint256 lpBalance = conicPool.deposit(depositAmount, 1, false);
        conicPool.withdraw(lpBalance, 1);
        lpBalance = conicPool.deposit(depositAmount, 1, false);
        conicPool.withdraw(lpBalance, 1);
        lpBalance = conicPool.deposit(depositAmount, 1, false);
        assertFalse(conicPool.rebalancingRewardActive(), "rebalancing reward should be inactive");
        underlying.approve(address(rewardsHandler), depositAmount);
        depositAmount = conicPool.computeTotalDeviation() / 2;
        (, uint256 cncReceived) = rewardsHandler.rebalance(address(conicPool), depositAmount, 0, 0);
        assertEq(cncReceived, 0, "should not receive any cnc");
        vm.stopPrank();
    }

    function testSwitchActiveMintingRebalancingRewardsHandler() public {
        address newRewardsHandler = _createNewRewardsHandler(false);
        vm.expectRevert("handler is still registered for a pool");
        rewardsHandler.switchMintingRebalancingRewardsHandler(newRewardsHandler);
    }

    function testSwitchInactiveMintingRebalancingRewardsHandler() public {
        inflationManager.removePoolRebalancingRewardHandler(
            address(conicPool),
            address(rewardsHandler)
        );
        address newRewardsHandler = _createNewRewardsHandler(false);
        rewardsHandler.switchMintingRebalancingRewardsHandler(newRewardsHandler);
        address[] memory minters = cnc.listMinters();
        assertContains(minters, newRewardsHandler);
        assertNotContains(minters, address(rewardsHandler));
    }

    function _createNewRewardsHandler(bool isMainnet) internal returns (address) {
        return
            address(
                new CNCMintingRebalancingRewardsHandler(
                    isMainnet ? IController(MainnetAddresses.CONTROLLER) : controller,
                    ICNCToken(isMainnet ? MainnetAddresses.CNC : controller.cncToken()),
                    ICNCMintingRebalancingRewardsHandler(
                        isMainnet ? MainnetAddresses.CNC_MINTING_REWARDS_HANDLER : address(0)
                    )
                )
            );
    }
}
