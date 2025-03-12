// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/InvariantTest.sol";

contract TestInvariantAccessControl is InvariantTest {
    using Math for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeTransferLib for ERC20;
    using TestMarketLib for TestMarket;

    uint256 internal initialized;

    function setUp() public virtual override {
        super.setUp();

        _targetDefaultSenders();

        _weightSelector(this.initialize.selector, 5);
        _weightSelector(this.supply.selector, 10);
        _weightSelector(this.supplyCollateral.selector, 15);
        _weightSelector(this.borrow.selector, 15);
        _weightSelector(this.repay.selector, 10);
        _weightSelector(this.withdraw.selector, 10);
        _weightSelector(this.withdrawCollateral.selector, 15);

        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
    }

    /* FUNCTIONS */

    function initialize(
        address addressesProvider,
        uint8 eModeCategoryId,
        address newPositionsManager,
        Types.Iterations memory newDefaultIterations
    ) external {
        vm.prank(msg.sender);
        try morpho.initialize(addressesProvider, eModeCategoryId, newPositionsManager, newDefaultIterations) {
            ++initialized;
        } catch (bytes memory reason) {
            revert(string(reason)); // Bubble up the revert reason.
        }
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

    function supplyCollateral(uint256 underlyingSeed, uint256 amount, address onBehalf) external {
        TestMarket storage market = testMarkets[_randomUnderlying(underlyingSeed)];
        amount = _boundSupply(market, amount);
        onBehalf = _randomSender(onBehalf);

        _deal(market.underlying, msg.sender, amount);

        vm.prank(msg.sender); // Cannot startPrank because `morpho.supplyCollateral` may revert and not call stopPrank.
        ERC20(market.underlying).safeApprove(address(morpho), amount);

        vm.prank(msg.sender);
        morpho.supplyCollateral(market.underlying, amount, onBehalf);
    }

    function borrow(uint256 underlyingSeed, uint256 amount, address receiver, uint256 maxIterations) external {
        TestMarket storage market = testMarkets[_randomBorrowableInEMode(underlyingSeed)];
        amount = _boundBorrow(market, amount);
        receiver = _boundReceiver(receiver);
        maxIterations = _boundMaxIterations(maxIterations);

        _borrowWithoutCollateral(msg.sender, market, amount, msg.sender, receiver, maxIterations);
    }

    function repay(uint256 underlyingSeed, uint256 amount, address onBehalf) external {
        TestMarket storage market = testMarkets[_randomBorrowableInEMode(underlyingSeed)];
        amount = _boundNotZero(amount);
        onBehalf = _randomSender(onBehalf);

        vm.prank(msg.sender); // Cannot startPrank because `morpho.repay` may revert and not call stopPrank.
        ERC20(market.underlying).safeApprove(address(morpho), amount);

        vm.prank(msg.sender);
        morpho.repay(market.underlying, amount, onBehalf);
    }

    function withdraw(uint256 underlyingSeed, uint256 amount, address receiver, uint256 maxIterations) external {
        TestMarket storage market = testMarkets[_randomUnderlying(underlyingSeed)];
        amount = _boundNotZero(amount);
        receiver = _boundReceiver(receiver);
        maxIterations = _boundMaxIterations(maxIterations);

        vm.prank(msg.sender);
        morpho.withdraw(market.underlying, amount, msg.sender, receiver, maxIterations);
    }

    function withdrawCollateral(uint256 underlyingSeed, uint256 amount, address receiver) external {
        TestMarket storage market = testMarkets[_randomUnderlying(underlyingSeed)];
        amount = _boundNotZero(amount);
        receiver = _boundReceiver(receiver);

        vm.prank(msg.sender);
        morpho.withdrawCollateral(market.underlying, amount, msg.sender, receiver);
    }

    /* INVARIANTS */

    function invariantInitialized() public {
        assertEq(initialized, 0, "initialized");
    }

    function invariantCannotBorrowOverLtv() public {
        address[] memory senders = targetSenders();

        for (uint256 i; i < senders.length; ++i) {
            address sender = senders[i];
            Types.LiquidityData memory liquidityData = morpho.liquidityData(sender);

            if (liquidityData.borrowable == 0) continue;

            for (uint256 j; j < borrowableInEModeUnderlyings.length; ++j) {
                TestMarket storage market = testMarkets[borrowableInEModeUnderlyings[j]];

                uint256 borrowable = (liquidityData.borrowable * 1 ether * 10 ** market.decimals).percentAdd(5) // Inflate borrowable because of WBTC decimals precision.
                    / (market.price * 1 ether);
                if (borrowable == 0 || borrowable > market.liquidity()) continue;

                vm.prank(sender);
                vm.expectRevert(Errors.UnauthorizedBorrow.selector);
                morpho.borrow(market.underlying, borrowable, sender, sender, 0);
            }
        }
    }

    function invariantCannotWithdrawOverLt() public {
        address[] memory senders = targetSenders();

        for (uint256 i; i < senders.length; ++i) {
            address sender = senders[i];
            address[] memory collaterals = morpho.userCollaterals(sender);
            Types.LiquidityData memory liquidityData = morpho.liquidityData(sender);

            if (liquidityData.debt == 0) continue;

            for (uint256 j; j < collaterals.length; ++j) {
                TestMarket storage market = testMarkets[collaterals[j]];

                uint256 withdrawable = rawCollateralValue(
                    // Inflate withdrawable by some bps because of WBTC decimals precision.
                    // Scale everything by 1 ether to avoid rounding errors due to market having less decimals than base currency.
                    (
                        ((liquidityData.maxDebt.zeroFloorSub(liquidityData.debt)) * 1 ether * 10 ** market.decimals)
                            .percentAdd(5) / (market.price * 1 ether)
                    ).percentDiv(market.getLt(eModeCategoryId))
                );
                if (withdrawable == 0 || withdrawable > morpho.collateralBalance(market.underlying, sender)) continue;

                vm.prank(sender);
                vm.expectRevert(Errors.UnauthorizedWithdraw.selector);
                morpho.withdrawCollateral(market.underlying, withdrawable, sender, sender);
            }
        }
    }
}
