// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/InvariantTest.sol";

contract TestInvariantMorpho is InvariantTest {
    using Math for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeTransferLib for ERC20;
    using TestMarketLib for TestMarket;

    uint256 internal initialized;

    mapping(address => bool) internal checkInvariantSupplyOrBorrowDeltaZero;
    mapping(address => bool) internal checkInvariantIdleOrSupplyDeltaZero;

    function setUp() public virtual override {
        super.setUp();

        for (uint256 i; i < allUnderlyings.length; ++i) {
            address underlying = allUnderlyings[i];

            checkInvariantSupplyOrBorrowDeltaZero[underlying] = true;
            checkInvariantIdleOrSupplyDeltaZero[underlying] = true;
        }

        _targetDefaultSenders();

        _weightSelector(this.increaseP2PDeltas.selector, 3);
        _weightSelector(this.setDefaultIterations.selector, 5);
        _weightSelector(this.supply.selector, 20);
        _weightSelector(this.borrow.selector, 20);
        _weightSelector(this.repay.selector, 20);
        _weightSelector(this.withdraw.selector, 20);
        _weightSelector(this.liquidate.selector, 5);

        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
    }

    /* FUNCTIONS */

    function increaseP2PDeltas(uint256 underlyingSeed, uint256 amount) external {
        address underlying = _randomUnderlying(underlyingSeed);

        Types.Market memory market = morpho.market(underlying);
        Types.Indexes256 memory indexes = morpho.updatedIndexes(underlying);

        uint256 minP2P = Math.min(
            market.deltas.supply.scaledP2PTotal.rayMul(indexes.supply.p2pIndex).zeroFloorSub(
                market.deltas.supply.scaledDelta.rayMul(indexes.supply.poolIndex)
            ),
            market.deltas.borrow.scaledP2PTotal.rayMul(indexes.borrow.p2pIndex).zeroFloorSub(
                market.deltas.borrow.scaledDelta.rayMul(indexes.borrow.poolIndex)
            )
        );
        if (minP2P == 0) return;

        amount = bound(amount, 1, minP2P);

        morpho.increaseP2PDeltas(underlying, amount); // Always call it as the DAO.

        checkInvariantSupplyOrBorrowDeltaZero[underlying] = false;
        checkInvariantIdleOrSupplyDeltaZero[underlying] = false;
    }

    function setDefaultIterations(Types.Iterations memory defaultIterations) external {
        defaultIterations.repay = uint128(_boundMaxIterations(defaultIterations.repay) / 3);
        defaultIterations.withdraw = uint128(_boundMaxIterations(defaultIterations.withdraw) / 3);

        morpho.setDefaultIterations(defaultIterations); // Always call it as the DAO.
    }

    function supply(uint256 underlyingSeed, uint256 amount, address onBehalf, uint256 maxIterations) external {
        TestMarket storage market = testMarkets[_randomUnderlying(underlyingSeed)];
        amount = _boundSupply(market, amount);
        onBehalf = _randomSender(onBehalf);
        maxIterations = _boundMaxIterations(maxIterations);

        _deal(market.underlying, msg.sender, amount);

        vm.prank(msg.sender); // Cannot startPrank because `morpho.supply` may revert and not call stopPrank.
        ERC20(market.underlying).safeApprove(address(morpho), amount);

        vm.prank(msg.sender);
        morpho.supply(market.underlying, amount, onBehalf, maxIterations);
    }

    function borrow(uint256 underlyingSeed, uint256 amount, address receiver, uint256 maxIterations) external {
        TestMarket storage market = testMarkets[_randomBorrowableInEMode(underlyingSeed)];
        amount = _boundBorrow(market, amount);
        receiver = _boundReceiver(receiver);
        maxIterations = _boundMaxIterations(maxIterations);

        _borrowWithoutCollateral(msg.sender, market, amount, msg.sender, receiver, maxIterations);
    }

    function repay(uint256 underlyingSeed, uint256 amount, address onBehalf, uint256 maxIterations) external {
        TestMarket storage market = testMarkets[_randomBorrowableInEMode(underlyingSeed)];

        if (morpho.borrowBalance(market.underlying, msg.sender) == 0) {
            vm.prank(msg.sender);
            return this.borrow(underlyingSeed, amount, onBehalf, maxIterations);
        }

        amount = _boundNotZero(amount);
        onBehalf = _randomSender(onBehalf);

        _deal(market.underlying, msg.sender, amount);

        vm.prank(msg.sender); // Cannot startPrank because `morpho.repay` may revert and not call stopPrank.
        ERC20(market.underlying).safeApprove(address(morpho), amount);

        vm.prank(msg.sender);
        morpho.repay(market.underlying, amount, onBehalf);
    }

    function withdraw(uint256 underlyingSeed, uint256 amount, address receiver, uint256 maxIterations) external {
        TestMarket storage market = testMarkets[_randomUnderlying(underlyingSeed)];

        if (morpho.supplyBalance(market.underlying, msg.sender) == 0) {
            vm.prank(msg.sender);
            return this.supply(underlyingSeed, amount, receiver, maxIterations);
        }

        amount = _boundNotZero(amount);
        receiver = _boundReceiver(receiver);
        maxIterations = _boundMaxIterations(maxIterations);

        vm.prank(msg.sender);
        morpho.withdraw(market.underlying, amount, msg.sender, receiver, maxIterations);
    }

    function liquidate(uint256 underlyingBorrowed, uint256 underlyingCollateral, address liquidatee, uint256 amount)
        external
    {
        TestMarket storage borrowedMarket = testMarkets[_randomUnderlying(underlyingBorrowed)];
        TestMarket storage collateralMarket = testMarkets[_randomUnderlying(underlyingCollateral)];
        liquidatee = _randomSender(liquidatee);

        vm.prank(msg.sender);
        morpho.liquidate(borrowedMarket.underlying, collateralMarket.underlying, liquidatee, amount);
    }

    /* INVARIANTS */

    function invariantBalanceOf() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            address underlying = allUnderlyings[i];
            Types.Market memory market = morpho.market(underlying);

            assertApproxEqAbs(ERC20(underlying).balanceOf(address(morpho)), market.idleSupply, 10);
        }
    }

    function invariantHealthFactor() public {
        (,,,,, uint256 healthFactor) = pool.getUserAccountData(address(morpho));

        assertGt(healthFactor, Constants.DEFAULT_LIQUIDATION_MAX_HF, "healthFactor");
    }

    function invariantCollateralsAndBorrows() public {
        address[] memory senders = targetSenders();

        for (uint256 i; i < senders.length; i++) {
            address[] memory userCollaterals = morpho.userCollaterals(senders[i]);
            address[] memory userBorrows = morpho.userBorrows(senders[i]);

            for (uint256 j; j < allUnderlyings.length; ++j) {
                assertEq(
                    morpho.collateralBalance(allUnderlyings[j], senders[i]) > 0,
                    _contains(userCollaterals, allUnderlyings[j]),
                    "collateral"
                );
                assertEq(
                    morpho.borrowBalance(allUnderlyings[j], senders[i]) > 0,
                    _contains(userBorrows, allUnderlyings[j]),
                    "borrow"
                );
            }
        }
    }

    function invariantSupplyOrBorrowDeltaZero() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            address underlying = allUnderlyings[i];
            Types.Market memory market = morpho.market(underlying);

            bool invariant = market.deltas.supply.scaledDelta == 0 || market.deltas.borrow.scaledDelta == 0;

            // If invariant holds again, it should hold at least until next time `increaseP2PDeltas` is called.
            if (!checkInvariantSupplyOrBorrowDeltaZero[underlying]) {
                checkInvariantSupplyOrBorrowDeltaZero[underlying] = invariant;

                continue;
            }

            assertTrue(invariant, "supply & borrow delta > 0");
        }
    }

    function invariantIdleOrSupplyDeltaZero() public {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            address underlying = allUnderlyings[i];
            Types.Market memory market = morpho.market(underlying);

            bool invariant = market.idleSupply == 0 || market.deltas.supply.scaledDelta == 0;

            // If invariant holds again, it should hold at least until next time `increaseP2PDeltas` is called.
            if (!checkInvariantIdleOrSupplyDeltaZero[underlying]) {
                checkInvariantIdleOrSupplyDeltaZero[underlying] = invariant;

                continue;
            }

            assertTrue(invariant, "idle supply & supply delta > 0");
        }
    }
}
