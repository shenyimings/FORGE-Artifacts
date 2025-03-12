// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationLiquidate is IntegrationTest {
    using WadRayMath for uint256;
    using stdStorage for StdStorage;
    using PercentageMath for uint256;
    using TestMarketLib for TestMarket;

    uint256 internal constant MIN_HF = 1e15;

    struct LiquidateTest {
        uint256 collateralBalanceBefore;
        uint256 borrowedBalanceBefore;
        uint256 repaid;
        uint256 seized;
    }

    function testShouldNotLiquidateHealthyUser(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        address borrower,
        uint256 borrowed,
        uint256 toRepay,
        uint256 healthFactor
    ) public {
        borrower = _boundReceiver(borrower);
        toRepay = bound(toRepay, 1, type(uint256).max);
        healthFactor = bound(healthFactor, Constants.DEFAULT_LIQUIDATION_MAX_HF.percentAdd(10), type(uint72).max);

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        _createPosition(borrowedMarket, collateralMarket, borrower, borrowed, 0, healthFactor);

        user.approve(borrowedMarket.underlying, toRepay);

        vm.expectRevert(Errors.UnauthorizedLiquidate.selector);
        user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, borrower, toRepay);
    }

    function testShouldNotSeizeCollateralOfUserNotOnCollateralMarket(
        uint256 collateralSeed,
        uint256 collateralSeedShift,
        uint256 borrowableSeed,
        address borrower,
        uint256 borrowed,
        uint256 promotionFactor,
        uint256 toRepay,
        uint256 healthFactor
    ) public {
        vm.assume(collateralSeed > collateralUnderlyings.length);
        collateralSeedShift = bound(collateralSeedShift, 1, collateralUnderlyings.length - 1);
        borrower = _boundReceiver(borrower);
        promotionFactor = bound(promotionFactor, 0, WadRayMath.WAD);
        toRepay = bound(toRepay, 1, type(uint256).max);
        healthFactor = bound(
            healthFactor,
            Constants.DEFAULT_LIQUIDATION_MIN_HF.percentAdd(10),
            Constants.DEFAULT_LIQUIDATION_MAX_HF.percentSub(10)
        );

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        _createPosition(borrowedMarket, collateralMarket, borrower, borrowed, promotionFactor, healthFactor);

        user.approve(borrowedMarket.underlying, toRepay);

        address collateralUnderlying = _randomCollateral(collateralSeed - collateralSeedShift);

        vm.expectRevert(Errors.CollateralIsZero.selector);
        user.liquidate(borrowedMarket.underlying, collateralUnderlying, borrower, toRepay);
    }

    function testShouldNotLiquidateUserNotInBorrowMarket(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        uint256 borrowableSeedShift,
        address borrower,
        uint256 borrowed,
        uint256 promotionFactor,
        uint256 toRepay,
        uint256 healthFactor
    ) public {
        vm.assume(borrowableSeed > borrowableInEModeUnderlyings.length);
        borrowableSeedShift = bound(borrowableSeedShift, 1, borrowableInEModeUnderlyings.length - 1);
        borrower = _boundReceiver(borrower);
        promotionFactor = bound(promotionFactor, 0, WadRayMath.WAD);
        toRepay = bound(toRepay, 1, type(uint256).max);
        healthFactor = bound(
            healthFactor,
            Constants.DEFAULT_LIQUIDATION_MIN_HF.percentAdd(10),
            Constants.DEFAULT_LIQUIDATION_MAX_HF.percentSub(10)
        );

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        _createPosition(borrowedMarket, collateralMarket, borrower, borrowed, promotionFactor, healthFactor);

        user.approve(borrowedMarket.underlying, toRepay);

        address borrowedUnderlying = _randomBorrowableInEMode(borrowableSeed - borrowableSeedShift);

        vm.expectRevert(Errors.DebtIsZero.selector);
        user.liquidate(borrowedUnderlying, collateralMarket.underlying, borrower, toRepay);
    }

    function testLiquidateUnhealthyUserWhenSentinelAllows(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        address borrower,
        uint256 borrowed,
        uint256 promotionFactor,
        uint256 toRepay,
        uint256 healthFactor
    ) public {
        borrower = _boundReceiver(borrower);
        promotionFactor = bound(promotionFactor, 0, WadRayMath.WAD);
        healthFactor = bound(
            healthFactor,
            Constants.DEFAULT_LIQUIDATION_MIN_HF.percentAdd(10),
            Constants.DEFAULT_LIQUIDATION_MAX_HF.percentSub(10)
        );

        oracleSentinel.setLiquidationAllowed(true);

        LiquidateTest memory test;

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        toRepay = bound(toRepay, borrowedMarket.minAmount, type(uint256).max);

        (test.borrowedBalanceBefore, test.collateralBalanceBefore) =
            _createPosition(borrowedMarket, collateralMarket, borrower, borrowed, promotionFactor, healthFactor);

        // Otherwise Morpho cannot perform a liquidation because its HF cannot cover the collateral seized.
        _deposit(collateralMarket.underlying, test.collateralBalanceBefore, address(morpho));

        user.approve(borrowedMarket.underlying, toRepay);

        _assertEvents(address(user), borrower, collateralMarket, borrowedMarket);

        (test.repaid, test.seized) =
            user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, borrower, toRepay);

        _assertDefaultLiquidation(test, borrowedMarket, collateralMarket, borrower);
    }

    function testShouldNotLiquidateUnhealthyUserWhenSentinelDisallows(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        address borrower,
        uint256 borrowed,
        uint256 promotionFactor,
        uint256 toRepay,
        uint256 healthFactor
    ) public {
        borrower = _boundReceiver(borrower);
        promotionFactor = bound(promotionFactor, 0, WadRayMath.WAD);
        toRepay = bound(toRepay, 1, type(uint256).max);
        healthFactor = bound(
            healthFactor,
            Constants.DEFAULT_LIQUIDATION_MIN_HF.percentAdd(10),
            Constants.DEFAULT_LIQUIDATION_MAX_HF.percentSub(10)
        );

        oracleSentinel.setLiquidationAllowed(false);

        LiquidateTest memory test;

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        (test.borrowedBalanceBefore, test.collateralBalanceBefore) =
            _createPosition(borrowedMarket, collateralMarket, borrower, borrowed, promotionFactor, healthFactor);

        vm.expectRevert(Errors.SentinelLiquidateNotEnabled.selector);
        user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, borrower, toRepay);
    }

    function testFullLiquidateUnhealthyUserWhenSentinelDisallowsButHealthFactorVeryLow(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        address borrower,
        uint256 borrowed,
        uint256 promotionFactor,
        uint256 toRepay,
        uint256 healthFactor
    ) public {
        borrower = _boundReceiver(borrower);
        promotionFactor = bound(promotionFactor, 0, WadRayMath.WAD);
        healthFactor = bound(healthFactor, MIN_HF, Constants.DEFAULT_LIQUIDATION_MIN_HF.percentSub(1));

        oracleSentinel.setLiquidationAllowed(false);

        LiquidateTest memory test;

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        (test.borrowedBalanceBefore, test.collateralBalanceBefore) =
            _createPosition(borrowedMarket, collateralMarket, borrower, borrowed, promotionFactor, healthFactor);
        toRepay = bound(toRepay, test.borrowedBalanceBefore, type(uint256).max);

        // Otherwise Morpho cannot perform a liquidation because its HF cannot cover the collateral seized.
        _deposit(collateralMarket.underlying, test.collateralBalanceBefore, address(morpho));

        user.approve(borrowedMarket.underlying, toRepay);

        _assertEvents(address(user), borrower, collateralMarket, borrowedMarket);

        (test.repaid, test.seized) =
            user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, borrower, toRepay);

        _assertFullLiquidation(test, borrowedMarket, collateralMarket, borrower);
    }

    function testLiquidateUnhealthyUserWhenSupplyCapExceeded(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        address borrower,
        uint256 borrowed,
        uint256 toRepay,
        uint256 supplyCap,
        uint256 healthFactor
    ) public {
        borrower = _boundReceiver(borrower);
        healthFactor = bound(
            healthFactor,
            Constants.DEFAULT_LIQUIDATION_MIN_HF.percentAdd(10),
            Constants.DEFAULT_LIQUIDATION_MAX_HF.percentSub(10)
        );

        LiquidateTest memory test;

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        toRepay = bound(toRepay, borrowedMarket.minAmount, type(uint256).max);

        (test.borrowedBalanceBefore, test.collateralBalanceBefore) =
            _createPosition(borrowedMarket, collateralMarket, borrower, borrowed, WadRayMath.WAD, healthFactor); // 100% peer-to-peer.

        // Otherwise Morpho cannot perform a liquidation because its HF cannot cover the collateral seized.
        _deposit(collateralMarket.underlying, test.collateralBalanceBefore, address(morpho));

        supplyCap = _boundSupplyCapExceeded(borrowedMarket, test.borrowedBalanceBefore, supplyCap);
        _setSupplyCap(borrowedMarket, supplyCap);

        user.approve(borrowedMarket.underlying, toRepay);

        _assertEvents(address(user), borrower, collateralMarket, borrowedMarket);

        (test.repaid, test.seized) =
            user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, borrower, toRepay);

        _assertDefaultLiquidation(test, borrowedMarket, collateralMarket, borrower);
    }

    function testFullLiquidateAnyUserOnDeprecatedMarket(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        address borrower,
        uint256 borrowed,
        uint256 promotionFactor,
        uint256 toRepay,
        uint256 healthFactor
    ) public {
        borrower = _boundReceiver(borrower);
        promotionFactor = bound(promotionFactor, 0, WadRayMath.WAD);
        healthFactor = bound(healthFactor, MIN_HF, type(uint72).max);

        LiquidateTest memory test;

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        (test.borrowedBalanceBefore, test.collateralBalanceBefore) =
            _createPosition(borrowedMarket, collateralMarket, borrower, borrowed, promotionFactor, healthFactor);
        toRepay = bound(toRepay, test.borrowedBalanceBefore, type(uint256).max);

        // Otherwise Morpho cannot perform a liquidation because its HF cannot cover the collateral seized.
        _deposit(collateralMarket.underlying, test.collateralBalanceBefore, address(morpho));

        morpho.setIsBorrowPaused(borrowedMarket.underlying, true);
        morpho.setIsDeprecated(borrowedMarket.underlying, true);

        user.approve(borrowedMarket.underlying, toRepay);

        _assertEvents(address(user), borrower, collateralMarket, borrowedMarket);

        (test.repaid, test.seized) =
            user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, borrower, toRepay);

        _assertFullLiquidation(test, borrowedMarket, collateralMarket, borrower);
    }

    function testShouldRevertWhenCollateralMarketNotCreated(
        uint256 seed,
        address underlying,
        address borrower,
        uint256 amount
    ) public {
        borrower = _boundReceiver(borrower);
        _assumeNotUnderlying(underlying);

        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(seed)];

        vm.expectRevert(); // Indexes calculation revert because indexes are updated before the market created check.
        user.liquidate(borrowedMarket.underlying, underlying, borrower, amount);
    }

    function testShouldRevertWhenBorrowMarketNotCreated(
        uint256 seed,
        address underlying,
        address borrower,
        uint256 amount
    ) public {
        borrower = _boundReceiver(borrower);
        _assumeNotUnderlying(underlying);

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(seed)];

        vm.expectRevert(); // Indexes calculation revert because indexes are updated before the market created check.
        user.liquidate(underlying, collateralMarket.underlying, borrower, amount);
    }

    function testShouldRevertWhenLiquidateBorrowIsPaused(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        address borrower,
        uint256 amount
    ) public {
        borrower = _boundReceiver(borrower);

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        morpho.setIsLiquidateBorrowPaused(borrowedMarket.underlying, true);

        vm.expectRevert(Errors.LiquidateBorrowIsPaused.selector);
        user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, borrower, amount);
    }

    function testShouldRevertWhenLiquidateCollateralIsPaused(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        address borrower,
        uint256 amount
    ) public {
        borrower = _boundReceiver(borrower);

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        morpho.setIsLiquidateCollateralPaused(collateralMarket.underlying, true);

        vm.expectRevert(Errors.LiquidateCollateralIsPaused.selector);
        user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, borrower, amount);
    }

    function testShouldRevertWhenBorrowerZero(uint256 collateralSeed, uint256 borrowableSeed, uint256 amount) public {
        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        vm.expectRevert(Errors.AddressIsZero.selector);
        user.liquidate(borrowedMarket.underlying, collateralMarket.underlying, address(0), amount);
    }

    function _assertDefaultLiquidation(
        LiquidateTest memory test,
        TestMarket storage borrowedMarket,
        TestMarket storage collateralMarket,
        address borrower
    ) internal {
        assertLe(test.seized, test.collateralBalanceBefore, "seized > collateral");
        assertLe(
            test.repaid,
            test.borrowedBalanceBefore.percentMul(Constants.DEFAULT_CLOSE_FACTOR),
            "repaid > borrowed * closeFactor"
        );

        assertApproxEqAbs(
            morpho.borrowBalance(borrowedMarket.underlying, borrower) + test.repaid,
            test.borrowedBalanceBefore,
            2,
            "borrowBalanceAfter != borrowedBalanceBefore - repaid"
        );
        assertApproxEqAbs(
            morpho.collateralBalance(collateralMarket.underlying, borrower) + test.seized,
            test.collateralBalanceBefore,
            1,
            "collateralBalanceAfter != collateralBalanceBefore - seized"
        );
    }

    function _assertFullLiquidation(
        LiquidateTest memory test,
        TestMarket storage borrowedMarket,
        TestMarket storage collateralMarket,
        address borrower
    ) internal {
        assertLe(test.seized, test.collateralBalanceBefore, "seized > collateral");
        assertLe(
            test.repaid,
            test.borrowedBalanceBefore.percentMul(Constants.MAX_CLOSE_FACTOR),
            "repaid > borrowed * closeFactor"
        );

        assertApproxEqAbs(
            morpho.borrowBalance(borrowedMarket.underlying, borrower) + test.repaid,
            test.borrowedBalanceBefore,
            2,
            "borrowBalanceAfter != borrowedBalanceBefore - repaid"
        );
        assertApproxEqAbs(
            morpho.collateralBalance(collateralMarket.underlying, borrower) + test.seized,
            test.collateralBalanceBefore,
            1,
            "collateralBalanceAfter != collateralBalanceBefore - seized"
        );

        // Either all the collateral got seized, or all the debt got repaid.
        if (morpho.collateralBalance(collateralMarket.underlying, borrower) != 0) {
            assertEq(morpho.borrowBalance(collateralMarket.underlying, borrower), 0, "borrowBalanceAfter != 0");
        }
    }

    function _assertEvents(
        address liquidator,
        address borrower,
        TestMarket storage collateralMarket,
        TestMarket storage borrowedMarket
    ) internal {
        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Repaid(liquidator, borrower, borrowedMarket.underlying, 0, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.CollateralWithdrawn(address(user), borrower, liquidator, collateralMarket.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Liquidated(address(user), borrower, borrowedMarket.underlying, 0, address(0), 0);
    }

    function _createPosition(
        TestMarket storage borrowedMarket,
        TestMarket storage collateralMarket,
        address borrower,
        uint256 borrowed,
        uint256 promotionFactor,
        uint256 healthFactor
    ) internal returns (uint256 borrowBalance, uint256 collateralBalance) {
        borrowed = _boundBorrow(borrowedMarket, borrowed);
        (, borrowed) = _borrowWithCollateral(
            borrower, collateralMarket, borrowedMarket, borrowed, borrower, borrower, DEFAULT_MAX_ITERATIONS
        );

        _promoteBorrow(promoter1, borrowedMarket, borrowed.wadMul(promotionFactor));

        uint256 newScaledCollateralBalance = morpho.scaledCollateralBalance(collateralMarket.underlying, borrower)
            .rayMul((collateralMarket.ltv - 10).rayDiv(collateralMarket.lt)).wadMul(healthFactor);

        stdstore.target(address(morpho)).sig("scaledCollateralBalance(address,address)").with_key(
            collateralMarket.underlying
        ).with_key(borrower).checked_write(newScaledCollateralBalance);

        borrowBalance = morpho.borrowBalance(borrowedMarket.underlying, borrower);
        collateralBalance = morpho.collateralBalance(collateralMarket.underlying, borrower);
    }
}
