// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "../helpers/ProductionTest.sol";

contract TestProdLifecycle is ProductionTest {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using TestMarketLib for TestMarket;

    struct MorphoPosition {
        uint256 scaledP2P;
        uint256 scaledPool;
        //
        uint256 p2p;
        uint256 pool;
        uint256 total;
    }

    struct MarketSideTest {
        Types.Market market;
        Types.Indexes256 updatedIndexes;
        uint256 amount;
        uint256 balanceBefore;
        //
        uint256 morphoPoolSupplyBefore;
        uint256 morphoPoolBorrowBefore;
        uint256 morphoUnderlyingBalanceBefore;
        //
        MorphoPosition position;
    }

    function _beforeSupplyCollateral(MarketSideTest memory collateral) internal virtual {}

    function _beforeSupply(MarketSideTest memory supply) internal virtual {}

    function _beforeBorrow(MarketSideTest memory borrow) internal virtual {}

    function _initMarketSideTest(TestMarket storage market, uint256 amount)
        internal
        view
        virtual
        returns (MarketSideTest memory test)
    {
        test.market = morpho.market(market.underlying);

        test.amount = amount;
    }

    function _updateTestBefore(MarketSideTest memory test) internal view {
        test.balanceBefore = ERC20(test.market.underlying).balanceOf(address(user));

        test.morphoPoolSupplyBefore = ERC20(test.market.aToken).balanceOf(address(morpho));
        test.morphoPoolBorrowBefore = ERC20(test.market.variableDebtToken).balanceOf(address(morpho));
        test.morphoUnderlyingBalanceBefore = ERC20(test.market.underlying).balanceOf(address(morpho));
    }

    function _updateCollateralPositionTest(MarketSideTest memory test) internal view {
        test.updatedIndexes = morpho.updatedIndexes(test.market.underlying);

        test.position.scaledPool = morpho.scaledCollateralBalance(test.market.underlying, address(user));

        test.position.pool = test.position.scaledPool.rayMulDown(test.updatedIndexes.supply.poolIndex);
        test.position.total = test.position.pool;
    }

    function _updateSupplyPositionTest(MarketSideTest memory test) internal view {
        test.updatedIndexes = morpho.updatedIndexes(test.market.underlying);

        test.position.scaledP2P = morpho.scaledP2PSupplyBalance(test.market.underlying, address(user));
        test.position.scaledPool = morpho.scaledPoolSupplyBalance(test.market.underlying, address(user));

        test.position.p2p = test.position.scaledP2P.rayMulDown(test.updatedIndexes.supply.p2pIndex);
        test.position.pool = test.position.scaledPool.rayMulDown(test.updatedIndexes.supply.poolIndex);
        test.position.total = test.position.p2p + test.position.pool;
    }

    function _updateBorrowPositionTest(MarketSideTest memory test) internal view {
        test.updatedIndexes = morpho.updatedIndexes(test.market.underlying);

        test.position.scaledP2P = morpho.scaledP2PBorrowBalance(test.market.underlying, address(user));
        test.position.scaledPool = morpho.scaledPoolBorrowBalance(test.market.underlying, address(user));

        test.position.p2p = test.position.scaledP2P.rayMulUp(test.updatedIndexes.borrow.p2pIndex);
        test.position.pool = test.position.scaledPool.rayMulUp(test.updatedIndexes.borrow.poolIndex);
        test.position.total = test.position.p2p + test.position.pool;
    }

    function _supplyCollateral(MarketSideTest memory collateral) internal virtual {
        _beforeSupplyCollateral(collateral);

        _updateTestBefore(collateral);

        user.approve(collateral.market.underlying, collateral.amount);
        user.supplyCollateral(collateral.market.underlying, collateral.amount, address(user));

        _updateCollateralPositionTest(collateral);
    }

    function _testSupplyCollateral(TestMarket storage market, MarketSideTest memory collateral) internal virtual {
        assertEq(
            ERC20(market.underlying).balanceOf(address(user)) + collateral.amount,
            collateral.balanceBefore,
            string.concat(market.symbol, " balance after collateral supply")
        );
        assertApproxEqAbs(
            collateral.position.total, collateral.amount, 2, string.concat(market.symbol, " total collateral")
        );

        assertEq(
            ERC20(market.underlying).balanceOf(address(morpho)),
            collateral.morphoUnderlyingBalanceBefore,
            string.concat(market.symbol, " morpho balance")
        );
        assertApproxEqAbs(
            ERC20(market.aToken).balanceOf(address(morpho)),
            collateral.morphoPoolSupplyBefore + collateral.position.pool,
            10,
            string.concat(market.symbol, " morpho pool supply")
        );
        assertApproxEqAbs(
            ERC20(market.variableDebtToken).balanceOf(address(morpho)),
            collateral.morphoPoolBorrowBefore,
            10,
            string.concat(market.symbol, " morpho pool borrow")
        );

        _forward(100_000);

        _updateCollateralPositionTest(collateral);
    }

    function _supply(MarketSideTest memory supply) internal virtual {
        _beforeSupply(supply);

        _updateTestBefore(supply);

        user.approve(supply.market.underlying, supply.amount);
        user.supply(supply.market.underlying, supply.amount, address(user));

        _updateSupplyPositionTest(supply);
    }

    function _testSupply(TestMarket storage market, MarketSideTest memory supply) internal virtual {
        assertEq(
            ERC20(market.underlying).balanceOf(address(user)) + supply.amount,
            supply.balanceBefore,
            string.concat(market.symbol, " balance after supply")
        );
        assertApproxEqAbs(supply.position.total, supply.amount, 3, string.concat(market.symbol, " total supply"));

        if (supply.market.pauseStatuses.isP2PDisabled) {
            assertEq(supply.position.scaledP2P, 0, string.concat(market.symbol, " borrow delta matched"));
        } else {
            uint256 availableBorrow =
                supply.market.deltas.borrow.scaledDelta.rayMul(supply.updatedIndexes.borrow.poolIndex);
            if (availableBorrow <= supply.amount) {
                assertGe(
                    supply.position.p2p, availableBorrow, string.concat(market.symbol, " borrow delta minimum match")
                );
            } else {
                assertApproxEqAbs(
                    supply.position.p2p, supply.amount, 1, string.concat(market.symbol, " borrow delta full match")
                );
            }
        }

        assertEq(
            ERC20(market.underlying).balanceOf(address(morpho)),
            supply.morphoUnderlyingBalanceBefore,
            string.concat(market.symbol, " morpho balance")
        );
        assertApproxEqAbs(
            ERC20(market.aToken).balanceOf(address(morpho)),
            supply.morphoPoolSupplyBefore + supply.position.pool,
            10,
            string.concat(market.symbol, " morpho pool supply")
        );
        assertApproxEqAbs(
            ERC20(market.variableDebtToken).balanceOf(address(morpho)) + supply.position.p2p,
            supply.morphoPoolBorrowBefore,
            10,
            string.concat(market.symbol, " morpho pool borrow")
        );

        _forward(100_000);

        _updateSupplyPositionTest(supply);
    }

    function _borrow(MarketSideTest memory borrow) internal virtual {
        _beforeBorrow(borrow);

        _updateTestBefore(borrow);

        user.borrow(borrow.market.underlying, borrow.amount);

        _updateBorrowPositionTest(borrow);
    }

    function _testBorrow(TestMarket storage market, MarketSideTest memory borrow) internal virtual {
        assertEq(
            ERC20(market.underlying).balanceOf(address(user)),
            borrow.balanceBefore + borrow.amount,
            string.concat(market.symbol, " balance after borrow")
        );
        assertApproxEqAbs(borrow.position.total, borrow.amount, 2, string.concat(market.symbol, " total borrow"));
        if (borrow.market.pauseStatuses.isP2PDisabled) {
            assertEq(borrow.position.scaledP2P, 0, string.concat(market.symbol, " supply delta matched"));
        } else {
            uint256 availableSupply = borrow.market.deltas.supply.scaledDelta.rayMul(
                borrow.updatedIndexes.supply.poolIndex
            ) + borrow.market.idleSupply;
            if (availableSupply <= borrow.amount) {
                assertGe(
                    borrow.position.p2p, availableSupply, string.concat(market.symbol, " supply delta minimum match")
                );
            } else {
                assertApproxEqAbs(
                    borrow.position.p2p, borrow.amount, 1, string.concat(market.symbol, " supply delta full match")
                );
            }
        }

        assertEq(
            ERC20(market.underlying).balanceOf(address(morpho)),
            borrow.morphoUnderlyingBalanceBefore,
            string.concat(market.symbol, " morpho balance")
        );
        assertApproxEqAbs(
            ERC20(market.aToken).balanceOf(address(morpho)) + borrow.position.p2p,
            borrow.morphoPoolSupplyBefore,
            10,
            string.concat(market.symbol, " morpho pool supply")
        );
        assertApproxEqAbs(
            ERC20(market.variableDebtToken).balanceOf(address(morpho)),
            borrow.morphoPoolBorrowBefore + borrow.position.pool,
            10,
            string.concat(market.symbol, " morpho pool borrow")
        );

        _forward(100_000);

        _updateBorrowPositionTest(borrow);
    }

    function _repay(MarketSideTest memory borrow) internal virtual {
        _updateBorrowPositionTest(borrow);

        _updateTestBefore(borrow);

        user.approve(borrow.market.underlying, borrow.position.total);
        user.repay(borrow.market.underlying, type(uint256).max, address(user));
    }

    function _testRepay(TestMarket storage market, MarketSideTest memory borrow) internal virtual {
        assertApproxEqAbs(
            ERC20(market.underlying).balanceOf(address(user)) + borrow.position.total,
            borrow.balanceBefore,
            1,
            string.concat(market.symbol, " after repay")
        );

        _updateBorrowPositionTest(borrow);

        assertEq(borrow.position.p2p, 0, string.concat(market.symbol, " p2p borrow after repay"));
        assertEq(borrow.position.pool, 0, string.concat(market.symbol, " pool borrow after repay"));
        assertEq(borrow.position.total, 0, string.concat(market.symbol, " total borrow after repay"));
    }

    function _withdraw(MarketSideTest memory supply) internal virtual {
        _updateSupplyPositionTest(supply);

        _updateTestBefore(supply);

        user.withdraw(supply.market.underlying, type(uint256).max);
    }

    function _testWithdraw(TestMarket storage market, MarketSideTest memory supply) internal virtual {
        assertApproxEqAbs(
            ERC20(market.underlying).balanceOf(address(user)),
            supply.balanceBefore + supply.position.total,
            1,
            string.concat(market.symbol, " after withdraw")
        );

        _updateSupplyPositionTest(supply);

        assertEq(supply.position.p2p, 0, string.concat(market.symbol, " p2p supply after withdraw"));
        assertEq(supply.position.pool, 0, string.concat(market.symbol, " pool supply after withdraw"));
        assertEq(supply.position.total, 0, string.concat(market.symbol, " total supply after withdraw"));
    }

    function _withdrawCollateral(MarketSideTest memory collateral) internal virtual {
        _updateCollateralPositionTest(collateral);

        _updateTestBefore(collateral);

        user.withdrawCollateral(collateral.market.underlying, type(uint256).max);
    }

    function _testWithdrawCollateral(TestMarket storage market, MarketSideTest memory collateral) internal virtual {
        assertApproxEqAbs(
            ERC20(market.underlying).balanceOf(address(user)),
            collateral.balanceBefore + collateral.position.total,
            1,
            string.concat(market.symbol, " collateral after withdraw")
        );

        _updateCollateralPositionTest(collateral);

        assertEq(collateral.position.p2p, 0, string.concat(market.symbol, " p2p supply after withdraw"));
        assertEq(collateral.position.pool, 0, string.concat(market.symbol, " pool supply after withdraw"));
        assertEq(collateral.position.total, 0, string.concat(market.symbol, " total supply after withdraw"));
    }

    function testShouldSupplyCollateralSupplyBorrowWithdrawRepayWithdrawCollateralAllMarkets(
        uint256 collateralSeed,
        uint256 borrowedSeed,
        uint256 collateralAmount,
        uint256 borrowedAmount
    ) public {
        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowedSeed)];

        borrowedAmount = _boundBorrow(borrowedMarket, borrowedAmount);
        collateralAmount = collateralMarket.minBorrowCollateral(borrowedMarket, borrowedAmount, eModeCategoryId);

        MarketSideTest memory collateral = _initMarketSideTest(collateralMarket, collateralAmount);
        vm.assume(!collateral.market.pauseStatuses.isSupplyCollateralPaused);

        MarketSideTest memory supply = _initMarketSideTest(borrowedMarket, borrowedAmount);
        vm.assume(!supply.market.pauseStatuses.isSupplyPaused);

        MarketSideTest memory borrow = _initMarketSideTest(borrowedMarket, borrowedAmount);
        vm.assume(!borrow.market.pauseStatuses.isBorrowPaused);

        _supplyCollateral(collateral);
        _testSupplyCollateral(collateralMarket, collateral);

        _supply(supply);
        _testSupply(borrowedMarket, supply);

        _borrow(borrow);
        _testBorrow(borrowedMarket, borrow);

        if (!borrow.market.pauseStatuses.isRepayPaused) {
            _repay(borrow);
            _testRepay(borrowedMarket, borrow);
        }

        if (!supply.market.pauseStatuses.isWithdrawPaused) {
            _withdraw(supply);
            _testWithdraw(borrowedMarket, supply);
        }

        if (collateral.market.pauseStatuses.isWithdrawCollateralPaused) return;

        _withdrawCollateral(collateral);
        _testWithdrawCollateral(collateralMarket, collateral);
    }

    function testShouldNotBorrowWithoutEnoughCollateral(
        uint256 collateralSeed,
        uint256 borrowedSeed,
        uint256 collateralAmount,
        uint256 borrowedAmount
    ) public {
        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowedSeed)];

        borrowedAmount = _boundBorrow(borrowedMarket, borrowedAmount);
        collateralAmount =
            collateralMarket.minBorrowCollateral(borrowedMarket, borrowedAmount, eModeCategoryId).percentSub(1_00);

        MarketSideTest memory collateral = _initMarketSideTest(collateralMarket, collateralAmount);
        vm.assume(!collateral.market.pauseStatuses.isSupplyCollateralPaused);

        MarketSideTest memory borrow = _initMarketSideTest(borrowedMarket, borrowedAmount);
        vm.assume(!borrow.market.pauseStatuses.isBorrowPaused);

        _supplyCollateral(collateral);

        vm.expectRevert(Errors.UnauthorizedBorrow.selector);
        user.borrow(borrowedMarket.underlying, borrowedAmount);
    }

    function testShouldNotSupplyZeroAmount() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.expectRevert(Errors.AmountIsZero.selector);
            user.supply(allUnderlyings[i], 0, address(user));
        }
    }

    function testShouldNotSupplyOnBehalfAddressZero(uint96 amount) public {
        vm.assume(amount > 0);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.expectRevert(Errors.AddressIsZero.selector);
            user.supply(allUnderlyings[i], amount, address(0));
        }
    }

    function testShouldNotSupplyCollateralZeroAmount() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.expectRevert(Errors.AmountIsZero.selector);
            user.supplyCollateral(allUnderlyings[i], 0, address(user));
        }
    }

    function testShouldNotSupplyCollateralOnBehalfAddressZero(uint96 amount) public {
        vm.assume(amount > 0);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.expectRevert(Errors.AddressIsZero.selector);
            user.supplyCollateral(allUnderlyings[i], amount, address(0));
        }
    }

    function testShouldNotBorrowZeroAmount() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.expectRevert(Errors.AmountIsZero.selector);
            user.borrow(allUnderlyings[i], 0);
        }
    }

    function testShouldNotRepayZeroAmount() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.expectRevert(Errors.AmountIsZero.selector);
            user.repay(allUnderlyings[i], 0, address(user));
        }
    }

    function testShouldNotWithdrawZeroAmount() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.expectRevert(Errors.AmountIsZero.selector);
            user.withdraw(allUnderlyings[i], 0);
        }
    }

    function testShouldNotWithdrawCollateralZeroAmount() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.expectRevert(Errors.AmountIsZero.selector);
            user.withdrawCollateral(allUnderlyings[i], 0);
        }
    }

    function testShouldNotSupplyWhenPaused(uint96 amount) public {
        vm.assume(amount > 0);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            TestMarket storage market = testMarkets[allUnderlyings[i]];
            if (!morpho.market(market.underlying).pauseStatuses.isSupplyPaused) continue;

            vm.expectRevert(Errors.SupplyIsPaused.selector);
            user.supply(market.underlying, amount);
        }
    }

    function testShouldNotSupplyCollateralWhenPaused(uint96 amount) public {
        vm.assume(amount > 0);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            TestMarket storage market = testMarkets[allUnderlyings[i]];
            if (!morpho.market(market.underlying).pauseStatuses.isSupplyCollateralPaused) continue;

            vm.expectRevert(Errors.SupplyCollateralIsPaused.selector);
            user.supplyCollateral(market.underlying, amount);
        }
    }

    function testShouldNotBorrowWhenPaused(uint96 amount) public {
        vm.assume(amount > 0);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            TestMarket storage market = testMarkets[allUnderlyings[i]];
            if (!morpho.market(market.underlying).pauseStatuses.isBorrowPaused) continue;

            vm.expectRevert(Errors.BorrowIsPaused.selector);
            user.borrow(market.underlying, amount);
        }
    }

    function testShouldNotRepayWhenPaused(uint96 amount) public {
        vm.assume(amount > 0);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            TestMarket storage market = testMarkets[allUnderlyings[i]];
            if (!morpho.market(market.underlying).pauseStatuses.isRepayPaused) continue;

            vm.expectRevert(Errors.RepayIsPaused.selector);
            user.repay(market.underlying, type(uint256).max);
        }
    }

    function testShouldNotWithdrawWhenPaused(uint96 amount) public {
        vm.assume(amount > 0);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            TestMarket storage market = testMarkets[allUnderlyings[i]];
            if (!morpho.market(market.underlying).pauseStatuses.isWithdrawPaused) continue;

            vm.expectRevert(Errors.WithdrawIsPaused.selector);
            user.withdraw(market.underlying, type(uint256).max);
        }
    }

    function testShouldNotWithdrawCollateralWhenPaused(uint96 amount) public {
        vm.assume(amount > 0);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            TestMarket storage market = testMarkets[allUnderlyings[i]];
            if (!morpho.market(market.underlying).pauseStatuses.isWithdrawCollateralPaused) continue;

            vm.expectRevert(Errors.WithdrawCollateralIsPaused.selector);
            user.withdrawCollateral(market.underlying, type(uint256).max);
        }
    }
}
