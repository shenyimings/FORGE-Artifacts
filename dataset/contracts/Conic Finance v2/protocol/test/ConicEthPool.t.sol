// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicPoolBaseTest.sol";
import "../interfaces/vendor/IBooster.sol";
import "../contracts/zaps/EthZap.sol";
import "../interfaces/vendor/IBaseRewardPool.sol";
import "./PoolHelpers.sol";

contract ConicEthPoolTest is ConicPoolBaseTest {
    using PoolHelpers for IConicPool;

    IConicPool public conicPool;
    IERC20Metadata public underlying;
    uint256 public decimals;

    function setUp() public override {
        super.setUp();
        underlying = IERC20Metadata(Tokens.WETH);
        decimals = underlying.decimals();
        setTokenBalance(bb8, address(underlying), 100 * 10 ** decimals);
        conicPool = _createConicPool(
            controller,
            rewardsHandler,
            locker,
            address(underlying),
            "Conic ETH",
            "cncETH",
            true
        );

        conicPool.addPool(CurvePools.STETH_ETH_POOL);
        conicPool.addPool(CurvePools.CBETH_ETH_POOL);

        controller.setAllowedMultipleDepositsWithdraws(bb8, true);

        IConicPool.PoolWeight[] memory weights = new IConicPool.PoolWeight[](2);
        weights[0] = IConicPool.PoolWeight(CurvePools.STETH_ETH_POOL, 0.6e18);
        weights[1] = IConicPool.PoolWeight(CurvePools.CBETH_ETH_POOL, 0.4e18);
        _setWeights(address(conicPool), weights);
    }

    function testInitialState() public {
        assertEq(address(conicPool.controller()), address(controller));
        assertEq(conicPool.lpToken().name(), "Conic ETH");
        assertEq(conicPool.lpToken().symbol(), "cncETH");
        assertEq(address(conicPool.underlying()), address(underlying));
        assertFalse(conicPool.isShutdown());
        assertFalse(conicPool.rebalancingRewardActive());
        assertEq(conicPool.depegThreshold(), 0.03e18);
        assertEq(conicPool.maxIdleCurveLpRatio(), 0.05e18);
    }

    function testDepositWithoutStaking() public {
        vm.startPrank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);

        uint256 balanceBefore = conicPool.lpToken().balanceOf(bb8);
        conicPool.deposit(10 * 10 ** decimals, 1, false);
        uint256 lpReceived = conicPool.lpToken().balanceOf(bb8) - balanceBefore;
        assertApproxEqRel(10 * 10 ** decimals, lpReceived, 0.01e18);

        // Validating that we received the Curve LP tokens
        address[] memory curvePools_ = conicPool.allPools();
        for (uint256 i; i < curvePools_.length; i++) {
            address curvePool_ = curvePools_[i];
            address lpToken_ = controller.curveRegistryCache().lpToken(curvePool_);
            uint256 lpTokenBalance_ = IERC20(lpToken_).balanceOf(address(conicPool));
            address rewardPoolAddress_ = controller.curveRegistryCache().getRewardPool(curvePool_);
            IBaseRewardPool rewardPool_ = IBaseRewardPool(rewardPoolAddress_);
            uint256 convexStakedBalance_ = rewardPool_.balanceOf(address(conicPool));
            uint256 totalLp_ = lpTokenBalance_ + convexStakedBalance_;
            assertTrue(totalLp_ > 0, "no LP tokens");
        }

        _checkAllocations();
    }

    function testNoDepositWhenPaused() public {
        controller.setPauseManager(address(this), true);
        conicPool.pause();
        vm.startPrank(bb8);
        underlying.approve(address(conicPool), 100_000 * 10 ** decimals);
        vm.expectRevert("paused");
        conicPool.deposit(10_000 * 10 ** decimals, 1, false);
    }

    function testDepositAndStake() public {
        vm.startPrank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);

        conicPool.deposit(10 * 10 ** decimals, 1);
        uint256 lpReceived = controller.lpTokenStaker().getUserBalanceForPool(
            address(conicPool),
            bb8
        );
        assertApproxEqRel(10 * 10 ** decimals, lpReceived, 0.01e18);
        _checkAllocations();
    }

    function testWidthrawWithoutStaking() public {
        vm.startPrank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);

        conicPool.deposit(10 * 10 ** decimals, 1, false);
        uint256 balanceBeforeWithdraw = underlying.balanceOf(bb8);
        uint256 lpBalanceBeforeWithdraw = conicPool.lpToken().balanceOf(bb8);
        conicPool.withdraw(5 * 10 ** decimals, 1);
        uint256 lpDiff = lpBalanceBeforeWithdraw - conicPool.lpToken().balanceOf(bb8);
        assertApproxEqRel(5 * 10 ** decimals, lpDiff, 0.01e18);
        uint256 underlyingReceived = underlying.balanceOf(bb8) - balanceBeforeWithdraw;
        assertApproxEqRel(5 * 10 ** decimals, underlyingReceived, 0.01e18);
        _checkAllocations();
    }

    function testWidthrawWithStaking() public {
        vm.startPrank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);

        conicPool.deposit(10 * 10 ** decimals, 1);
        uint256 balanceBeforeWithdraw = underlying.balanceOf(bb8);
        uint256 lpBalanceBeforeWithdraw = controller.lpTokenStaker().getUserBalanceForPool(
            address(conicPool),
            bb8
        );
        conicPool.unstakeAndWithdraw(5 * 10 ** decimals, 1);
        uint256 lpDiff = lpBalanceBeforeWithdraw -
            controller.lpTokenStaker().getUserBalanceForPool(address(conicPool), bb8);
        assertApproxEqRel(5 * 10 ** decimals, lpDiff, 0.01e18, "lpDiff");
        uint256 underlyingReceived = underlying.balanceOf(bb8) - balanceBeforeWithdraw;
        assertApproxEqRel(5 * 10 ** decimals, underlyingReceived, 0.01e18, "underlyingReceived");
        _checkAllocations();
    }

    function testRebalance() public {
        vm.startPrank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);

        conicPool.deposit(10 * 10 ** decimals, 1);
        vm.stopPrank();

        skip(14 days);

        IConicPool.PoolWeight[] memory newWeights = new IConicPool.PoolWeight[](2);
        newWeights[0] = IConicPool.PoolWeight(CurvePools.STETH_ETH_POOL, 0.3e18);
        newWeights[1] = IConicPool.PoolWeight(CurvePools.CBETH_ETH_POOL, 0.7e18);
        _setWeights(address(conicPool), newWeights);

        skip(1 hours);

        assertTrue(conicPool.rebalancingRewardActive());

        uint256 deviationBefore = conicPool.computeTotalDeviation();
        uint256 cncBalanceBefore = IERC20(controller.cncToken()).balanceOf(bb8);
        vm.prank(bb8);
        conicPool.deposit(10 * 10 ** decimals, 1);
        uint256 deviationAfter = conicPool.computeTotalDeviation();
        assertLt(deviationAfter, deviationBefore);
        uint256 cncBalanceAfter = IERC20(controller.cncToken()).balanceOf(bb8);
        assertGt(cncBalanceAfter, cncBalanceBefore);
    }

    function testClaimRewards() public {
        vm.startPrank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);
        IRewardManager rewardManager = conicPool.rewardManager();

        conicPool.deposit(10 * 10 ** decimals, 1);
        skip(1 days);
        (uint256 cncRewards, uint256 crvRewards, uint256 cvxRewards) = rewardManager
            .claimableRewards(bb8);
        assertGt(cncRewards, 0);
        assertGt(crvRewards, 0);
        assertGt(cvxRewards, 0);

        (uint256 cncClaimed, uint256 crvClaimed, uint256 cvxClaimed) = rewardManager
            .claimEarnings();
        assertEq(cncClaimed, cncRewards);
        assertEq(crvClaimed, crvRewards);
        assertEq(cvxClaimed, cvxRewards);
    }

    function testHandleInvalidConvexPid() public {
        address[] memory pools = conicPool.allPools();
        address curvePool = pools[0];
        vm.expectRevert("convex pool pid is shutdown");
        conicPool.handleInvalidConvexPid(curvePool);
        uint256 pid = controller.curveRegistryCache().getPid(curvePool);
        vm.mockCall(
            address(controller.curveRegistryCache().BOOSTER()),
            abi.encodeWithSelector(IBooster.poolInfo.selector, pid),
            abi.encode(
                address(0), // lpToken
                address(0), // token,
                address(0), // gauge,
                address(0), // crvRewards,
                address(0), // stash,
                true // shutdown
            )
        );

        conicPool.handleInvalidConvexPid(curvePool);
        assertEq(conicPool.getPoolWeight(curvePool), 0);
        _ensureWeightsSumTo1(conicPool);
    }

    function testHandleDepeggedPool() public {
        address[] memory pools = conicPool.allPools();
        address curvePool = pools[0];
        vm.expectRevert("pool is not depegged");
        conicPool.handleDepeggedCurvePool(curvePool);

        address lpToken = controller.curveRegistryCache().lpToken(curvePool);
        uint256 price = controller.priceOracle().getUSDPrice(lpToken);
        vm.mockCall(
            address(controller.priceOracle()),
            abi.encodeWithSelector(IOracle.getUSDPrice.selector, lpToken),
            abi.encode((price * 95) / 100)
        );
        conicPool.handleDepeggedCurvePool(curvePool);
        assertEq(conicPool.getPoolWeight(curvePool), 0);
        _ensureWeightsSumTo1(conicPool);
    }

    function testRemovePool() public {
        vm.prank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);
        vm.prank(bb8);
        conicPool.deposit(10 * 10 ** decimals, 1, false);

        address[] memory pools = conicPool.allPools();
        address curvePool = pools[0];

        vm.expectRevert("pool has allocated funds");
        conicPool.removePool(curvePool);

        skip(14 days);

        IConicPool.PoolWeight[] memory newWeights = new IConicPool.PoolWeight[](2);
        newWeights[0] = IConicPool.PoolWeight(CurvePools.STETH_ETH_POOL, 0);
        newWeights[1] = IConicPool.PoolWeight(CurvePools.CBETH_ETH_POOL, 1e18);
        _setWeights(address(conicPool), newWeights);

        vm.prank(bb8);
        conicPool.withdraw(9 * 10 ** decimals, 1);

        conicPool.removePool(curvePool);
        address[] memory newPools = conicPool.allPools();
        assertEq(newPools.length, pools.length - 1);
        for (uint256 i = 0; i < newPools.length; i++) {
            if (newPools[i] == curvePool) fail("pool not removed");
        }
    }

    function testRemoveAndAddPool() public {
        vm.prank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);
        vm.prank(bb8);
        conicPool.deposit(10 * 10 ** decimals, 1, false);
        address[] memory pools = conicPool.allPools();
        address curvePool = pools[0];

        skip(14 days);

        IConicPool.PoolWeight[] memory newWeights = new IConicPool.PoolWeight[](2);
        newWeights[0] = IConicPool.PoolWeight(CurvePools.STETH_ETH_POOL, 0);
        newWeights[1] = IConicPool.PoolWeight(CurvePools.CBETH_ETH_POOL, 1e18);
        _setWeights(address(conicPool), newWeights);

        vm.prank(bb8);
        conicPool.withdraw(9 * 10 ** decimals, 1);
        conicPool.removePool(curvePool);

        conicPool.addPool(curvePool);
        address[] memory newPools = conicPool.allPools();
        assertEq(newPools.length, pools.length);
        for (uint256 i = 0; i < newPools.length; i++) {
            for (uint256 j = 0; j < newPools.length; j++) {
                if (newPools[i] == pools[j]) break;
                if (j == newPools.length - 1) fail("pool not added");
            }
        }
    }

    function testSetMaxIdleCurveLpRatio() public {
        uint256 currentRatio = conicPool.maxIdleCurveLpRatio();
        vm.expectRevert("same as current");
        conicPool.setMaxIdleCurveLpRatio(currentRatio);

        vm.expectRevert("ratio exceeds upper bound");
        conicPool.setMaxIdleCurveLpRatio(0.21e18);

        conicPool.setMaxIdleCurveLpRatio(0.15e18);
        assertEq(conicPool.maxIdleCurveLpRatio(), 0.15e18);
    }

    function testUpdateDepegThreshold() public {
        vm.expectRevert("invalid depeg threshold");
        conicPool.updateDepegThreshold(0.009e18);

        vm.expectRevert("invalid depeg threshold");
        conicPool.updateDepegThreshold(0.11e18);

        conicPool.updateDepegThreshold(0.05e18);
        assertEq(conicPool.depegThreshold(), 0.05e18);
    }

    function testShutdown() public {
        vm.expectRevert("not authorized");
        conicPool.shutdownPool();

        vm.prank(bb8);
        underlying.approve(address(conicPool), 100 * 10 ** decimals);
        vm.prank(bb8);
        conicPool.deposit(10 * 10 ** decimals, 1, false);

        vm.prank(address(controller));
        conicPool.shutdownPool();
        assertTrue(conicPool.isShutdown());

        vm.prank(bb8);
        vm.expectRevert("pool is shutdown");
        conicPool.deposit(10 * 10 ** decimals, 1, false);

        uint256 balanceBeforeWithdraw = underlying.balanceOf(bb8);
        uint256 lpAmount = conicPool.lpToken().balanceOf(bb8);
        assertApproxEqRel(lpAmount, 10 * 10 ** decimals, 0.01e18, "wrong lp amount");
        vm.prank(bb8);
        conicPool.withdraw(lpAmount, 1);
        uint256 underlyingReceived = underlying.balanceOf(bb8) - balanceBeforeWithdraw;
        assertApproxEqRel(
            10 * 10 ** decimals,
            underlyingReceived,
            0.01e18,
            "wrong underlying received"
        );
    }

    function testPoolsNotDepegged() public {
        vm.expectRevert("pool is not depegged");
        conicPool.handleDepeggedCurvePool(CurvePools.STETH_ETH_POOL);

        vm.expectRevert("pool is not depegged");
        conicPool.handleDepeggedCurvePool(CurvePools.CBETH_ETH_POOL);
    }

    function testZap() public {
        EthZap ethZap = new EthZap(address(conicPool));
        IWETH weth_ = IWETH(Tokens.WETH);
        uint256 wethBalance = weth_.balanceOf(address(bb8));
        vm.startPrank(bb8);
        weth_.withdraw(wethBalance);
        uint256 depositAmount_ = 10 * 10 ** decimals;

        vm.expectRevert("wrong amount");
        ethZap.depositFor{value: depositAmount_ / 2}(
            address(bb8),
            depositAmount_,
            (depositAmount_ * 9) / 10,
            true
        );

        ethZap.depositFor{value: depositAmount_}(
            address(bb8),
            depositAmount_,
            (depositAmount_ * 9) / 10,
            true
        );

        uint256 lpReceived = controller.lpTokenStaker().getUserBalanceForPool(
            address(conicPool),
            bb8
        );
        assertApproxEqRel(depositAmount_, lpReceived, 0.01e18);

        uint256 balanceBeforeWithdraw = bb8.balance;
        conicPool.unstakeAndWithdraw(lpReceived, 1, address(ethZap));
        assertApproxEqRel(bb8.balance - balanceBeforeWithdraw, depositAmount_, 0.01e18);
    }

    function _checkAllocations() internal {
        IConicPool.PoolWithAmount[] memory allocations = conicPool.getAllocatedUnderlying();
        uint256 totalUnderlying = conicPool.totalUnderlying();
        IConicPool.PoolWeight[] memory weights = conicPool.getWeights();
        for (uint256 i = 0; i < allocations.length; i++) {
            uint256 expected = (totalUnderlying * weights[i].weight) / 1e18;
            assertApproxEqRel(allocations[i].amount, expected, 0.04e18, "wrong allocation");
        }
        assertLt(conicPool.computeDeviationRatio(), 0.04e18, "deviation too high");
    }
}
