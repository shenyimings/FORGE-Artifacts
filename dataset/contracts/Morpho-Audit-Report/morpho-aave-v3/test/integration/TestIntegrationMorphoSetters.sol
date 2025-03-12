// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationMorphoSetters is IntegrationTest {
    using WadRayMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    uint16 private constant DEFAULT_RESERVE_FACTOR = 1_000;
    uint16 private constant DEFAULT_P2P_INDEX_CURSOR = 1_000;
    address private constant DEFAULT_PRANKER = address(uint160(uint256(keccak256(abi.encode(42069)))));

    function testShouldBeInitialized() public {
        assertEq(Ownable2StepUpgradeable(address(morpho)).owner(), address(this), "owner");
        assertEq(morpho.pool(), address(pool), "pool");
        assertEq(morpho.addressesProvider(), address(addressesProvider), "addressesProvider");
        assertEq(morpho.eModeCategoryId(), eModeCategoryId, "eModeCategoryId");
        Types.Iterations memory iterations = morpho.defaultIterations();
        assertEq(iterations.repay, 10, "defaultIterations.repay");
        assertEq(iterations.withdraw, 10, "defaultIterations.withdraw");
        assertEq(pool.getUserEMode(address(morpho)), eModeCategoryId, "getUserEMode");
        assertEq(morpho.positionsManager(), address(positionsManager), "positionsManager");
    }

    function testShouldNotCreateSiloedBorrowMarket(uint16 reserveFactor, uint16 p2pIndexCursor) public {
        DataTypes.ReserveData memory reserve = pool.getReserveData(link);
        reserve.configuration.setSiloedBorrowing(true);
        vm.mockCall(address(pool), abi.encodeCall(pool.getReserveData, (link)), abi.encode(reserve));

        vm.expectRevert(Errors.SiloedBorrowMarket.selector);
        morpho.createMarket(link, reserveFactor, p2pIndexCursor);
    }

    function testCreateMarketRevertsIfNotOwner(uint16 reserveFactor, uint16 p2pIndexCursor) public {
        reserveFactor = uint16(bound(reserveFactor, 0, PercentageMath.PERCENTAGE_FACTOR));
        p2pIndexCursor = uint16(bound(p2pIndexCursor, 0, PercentageMath.PERCENTAGE_FACTOR));
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.createMarket(link, reserveFactor, p2pIndexCursor);
    }

    function testCreateMarketRevertsIfZeroAddressUnderlying(uint16 reserveFactor, uint16 p2pIndexCursor) public {
        reserveFactor = uint16(bound(reserveFactor, 0, PercentageMath.PERCENTAGE_FACTOR));
        p2pIndexCursor = uint16(bound(p2pIndexCursor, 0, PercentageMath.PERCENTAGE_FACTOR));
        vm.expectRevert(Errors.AddressIsZero.selector);
        morpho.createMarket(address(0), reserveFactor, p2pIndexCursor);
    }

    function testCreateMarketRevertsIfMarketNotOnAave(address underlying, uint16 reserveFactor, uint16 p2pIndexCursor)
        public
    {
        vm.assume(!_containsUnderlying(underlying));
        vm.assume(underlying != address(0));

        reserveFactor = uint16(bound(reserveFactor, 0, PercentageMath.PERCENTAGE_FACTOR));
        p2pIndexCursor = uint16(bound(p2pIndexCursor, 0, PercentageMath.PERCENTAGE_FACTOR));
        vm.expectRevert(Errors.MarketIsNotListedOnAave.selector);
        morpho.createMarket(underlying, reserveFactor, p2pIndexCursor);
    }

    function testCreateMarketRevertsIfMarketAlreadyCreated(
        uint16 reserveFactor1,
        uint16 p2pIndexCursor1,
        uint16 reserveFactor2,
        uint16 p2pIndexCursor2
    ) public {
        reserveFactor1 = uint16(bound(reserveFactor1, 0, PercentageMath.PERCENTAGE_FACTOR));
        p2pIndexCursor1 = uint16(bound(p2pIndexCursor1, 0, PercentageMath.PERCENTAGE_FACTOR));
        reserveFactor2 = uint16(bound(reserveFactor2, 0, PercentageMath.PERCENTAGE_FACTOR));
        p2pIndexCursor2 = uint16(bound(p2pIndexCursor2, 0, PercentageMath.PERCENTAGE_FACTOR));
        morpho.createMarket(link, reserveFactor1, p2pIndexCursor1);
        vm.expectRevert(Errors.MarketAlreadyCreated.selector);
        morpho.createMarket(link, reserveFactor2, p2pIndexCursor2);
    }

    function testCreateMarket(uint16 reserveFactor, uint16 p2pIndexCursor) public {
        reserveFactor = uint16(bound(reserveFactor, 0, PercentageMath.PERCENTAGE_FACTOR));
        p2pIndexCursor = uint16(bound(p2pIndexCursor, 0, PercentageMath.PERCENTAGE_FACTOR));

        uint256 expectedPoolSupplyIndex = pool.getReserveNormalizedIncome(link);
        uint256 expectedPoolBorrowIndex = pool.getReserveNormalizedVariableDebt(link);

        vm.expectEmit(true, true, true, true);
        emit Events.MarketCreated(link);
        vm.expectEmit(true, true, true, true);
        emit Events.IndexesUpdated(
            link, expectedPoolSupplyIndex, WadRayMath.RAY, expectedPoolBorrowIndex, WadRayMath.RAY
        );
        vm.expectEmit(true, true, true, true);
        emit Events.ReserveFactorSet(link, reserveFactor);
        vm.expectEmit(true, true, true, true);
        emit Events.P2PIndexCursorSet(link, p2pIndexCursor);
        morpho.createMarket(link, reserveFactor, p2pIndexCursor);

        Types.Market memory market = morpho.market(link);
        DataTypes.ReserveData memory reserveData = pool.getReserveData(link);

        assertEq(market.indexes.supply.poolIndex, expectedPoolSupplyIndex, "supply pool index");
        assertEq(market.indexes.supply.p2pIndex, WadRayMath.RAY, "supply p2p index");
        assertEq(market.indexes.borrow.poolIndex, expectedPoolBorrowIndex, "borrow pool index");
        assertEq(market.indexes.borrow.p2pIndex, WadRayMath.RAY, "borrow p2p index");
        assertEq(market.deltas.supply.scaledDelta, 0, "supply scaled delta");
        assertEq(market.deltas.supply.scaledP2PTotal, 0, "supply scaled p2p total");
        assertEq(market.deltas.borrow.scaledDelta, 0, "borrow scaled delta");
        assertEq(market.deltas.borrow.scaledP2PTotal, 0, "borrow scaled p2p total");
        assertEq(market.underlying, link, "underlying");
        assertFalse(market.pauseStatuses.isP2PDisabled, "is p2p disabled");
        assertFalse(market.pauseStatuses.isSupplyPaused, "is supply paused");
        assertFalse(market.pauseStatuses.isSupplyCollateralPaused, "is supply collateral paused");
        assertFalse(market.pauseStatuses.isBorrowPaused, "is borrow paused");
        assertFalse(market.pauseStatuses.isWithdrawPaused, "is withdraw paused");
        assertFalse(market.pauseStatuses.isWithdrawCollateralPaused, "is withdraw collateral paused");
        assertFalse(market.pauseStatuses.isRepayPaused, "is repay paused");
        assertFalse(market.pauseStatuses.isLiquidateCollateralPaused, "is liquidate collateral paused");
        assertFalse(market.pauseStatuses.isLiquidateBorrowPaused, "is liquidate borrow paused");
        assertFalse(market.pauseStatuses.isDeprecated, "is deprecated");
        assertEq(market.variableDebtToken, reserveData.variableDebtTokenAddress, "variable debt token");
        assertEq(market.lastUpdateTimestamp, block.timestamp, "last update timestamp");
        assertEq(market.reserveFactor, reserveFactor, "reserve factor");
        assertEq(market.p2pIndexCursor, p2pIndexCursor, "p2p index cursor");
        assertEq(market.aToken, reserveData.aTokenAddress, "aToken");
        assertEq(market.stableDebtToken, reserveData.stableDebtTokenAddress, "stable debt token");
        assertEq(market.idleSupply, 0, "idle supply");

        assertEq(ERC20(link).allowance(address(morpho), address(pool)), type(uint256).max);
    }

    function testClaimToTreasuryOnlyOwner() public {
        address[] memory underlyings = new address[](1);
        underlyings[0] = link;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.claimToTreasury(underlyings, amounts);
    }

    function testClaimToTreasuryRevertsIfTreasuryVaultIsZero() public {
        morpho.setTreasuryVault(address(0));
        address[] memory underlyings = new address[](1);
        underlyings[0] = link;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;
        vm.expectRevert(Errors.AddressIsZero.selector);
        morpho.claimToTreasury(underlyings, amounts);
    }

    function testClaimToTreasuryDoesNothingIfMarketNotCreated(uint256 amount, address treasury) public {
        vm.assume(treasury != address(0));
        morpho.setTreasuryVault(treasury);
        address[] memory underlyings = new address[](1);
        underlyings[0] = link;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        deal(underlyings[0], address(morpho), amount);

        uint256 treasuryBalanceBefore = ERC20(underlyings[0]).balanceOf(treasury);

        morpho.claimToTreasury(underlyings, amounts);

        assertEq(amount, ERC20(underlyings[0]).balanceOf(address(morpho)), "morpho balance after");
        assertEq(ERC20(underlyings[0]).balanceOf(treasury), treasuryBalanceBefore, "treasury balance after");
    }

    function testClaimToTreasury(uint256 seed, uint256 amount, uint256 balance, uint256 idleSupply, address treasury)
        public
    {
        vm.assume(treasury != address(0));
        amount = _boundAmount(amount);
        balance = _boundAmount(balance);
        idleSupply = _boundAmount(idleSupply);

        address[] memory underlyings = new address[](1);
        underlyings[0] = _randomBorrowableInEMode(seed);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        morpho.setTreasuryVault(treasury);

        _increaseIdleSupply(promoter1, testMarkets[underlyings[0]], idleSupply);
        // There might be rounding errors in the increase of idle supply, but this test is out of scope for dealing with that
        // So it's just reassigned here.
        idleSupply = morpho.market(underlyings[0]).idleSupply;
        balance = Math.max(balance, idleSupply);

        uint256 treasuryBalanceBefore = ERC20(underlyings[0]).balanceOf(treasury);
        uint256 expectedClaimed = Math.min(amount, balance - idleSupply);

        deal(underlyings[0], address(morpho), balance);

        assertEq(morpho.market(underlyings[0]).idleSupply, idleSupply, "idle supply before");

        morpho.claimToTreasury(underlyings, amounts);

        assertEq(ERC20(underlyings[0]).balanceOf(address(morpho)), balance - expectedClaimed, "morpho balance after");
        assertEq(
            ERC20(underlyings[0]).balanceOf(treasury), expectedClaimed + treasuryBalanceBefore, "treasury balance after"
        );
        assertEq(morpho.market(underlyings[0]).idleSupply, idleSupply, "idle supply after");
    }

    function testSetDefaultIterationsFailsIfNotOwner(uint128 repay, uint128 withdraw) public {
        Types.Iterations memory iterations = Types.Iterations(repay, withdraw);
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setDefaultIterations(iterations);
    }

    function testSetDefaultIterations(uint128 repay, uint128 withdraw) public {
        Types.Iterations memory iterations = Types.Iterations(repay, withdraw);
        vm.expectEmit(true, true, true, true);
        emit Events.DefaultIterationsSet(repay, withdraw);
        morpho.setDefaultIterations(iterations);
        assertEq(morpho.defaultIterations().repay, repay);
        assertEq(morpho.defaultIterations().withdraw, withdraw);
    }

    function testSetPositionsManagerFailsIfNotOwner(address positionsManager) public {
        vm.assume(positionsManager != address(0));
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setPositionsManager(positionsManager);
    }

    function testSetPositionsManagerFailsIfZero() public {
        vm.expectRevert(Errors.AddressIsZero.selector);
        morpho.setPositionsManager(address(0));
    }

    function testSetPositionsManager(address positionsManager) public {
        vm.assume(positionsManager != address(0));
        vm.expectEmit(true, true, true, true);
        emit Events.PositionsManagerSet(positionsManager);
        morpho.setPositionsManager(positionsManager);
        assertEq(morpho.positionsManager(), positionsManager);
    }

    function testSetRewardsManagerFailsIfNotOwner(address rewardsManager) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setRewardsManager(rewardsManager);
    }

    function testSetRewardsManager(address rewardsManager) public {
        vm.assume(rewardsManager != address(0));
        vm.expectEmit(true, true, true, true);
        emit Events.RewardsManagerSet(rewardsManager);
        morpho.setRewardsManager(rewardsManager);
        assertEq(morpho.rewardsManager(), rewardsManager);
    }

    function testSetTreasuryVaultFailsIfNotOwner(address treasuryVault) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setTreasuryVault(treasuryVault);
    }

    function testSetTreasuryVault(address treasuryVault) public {
        vm.expectEmit(true, true, true, true);
        emit Events.TreasuryVaultSet(treasuryVault);
        morpho.setTreasuryVault(treasuryVault);
        assertEq(morpho.treasuryVault(), treasuryVault);
    }

    function testSetReserveFactorFailsIfNotOwner(uint256 seed, uint16 reserveFactor) public {
        address underlying = _randomUnderlying(seed);
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setReserveFactor(underlying, reserveFactor);
    }

    function testSetReserveFactorFailsIfMarketNotCreated(address underlying, uint16 reserveFactor) public {
        vm.assume(!_containsUnderlying(underlying));
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setReserveFactor(underlying, reserveFactor);
    }

    function testSetReserveFactor(uint256 seed, uint16 reserveFactor) public {
        reserveFactor = uint16(bound(reserveFactor, 0, PercentageMath.PERCENTAGE_FACTOR));
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.ReserveFactorSet(underlying, reserveFactor);
        morpho.setReserveFactor(underlying, reserveFactor);
        assertEq(morpho.market(underlying).reserveFactor, reserveFactor);
    }

    function testSetP2PIndexCursorFailsIfNotOwner(uint256 seed, uint16 p2pIndexCursor) public {
        address underlying = _randomUnderlying(seed);
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setP2PIndexCursor(underlying, p2pIndexCursor);
    }

    function testSetP2PIndexCursorFailsIfMarketNotCreated(uint16 p2pIndexCursor) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setP2PIndexCursor(link, p2pIndexCursor);
    }

    function testSetP2PIndexCursor(uint256 seed, uint16 p2pIndexCursor) public {
        p2pIndexCursor = uint16(bound(p2pIndexCursor, 0, PercentageMath.PERCENTAGE_FACTOR));
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.P2PIndexCursorSet(underlying, p2pIndexCursor);
        morpho.setP2PIndexCursor(underlying, p2pIndexCursor);
        assertEq(morpho.market(underlying).p2pIndexCursor, p2pIndexCursor);
    }

    function testSetIsClaimRewardsPausedFailsIfNotOwner(bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsClaimRewardsPaused(paused);
    }

    function testSetIsClaimRewardsPaused(bool paused) public {
        vm.expectEmit(true, true, true, true);
        emit Events.IsClaimRewardsPausedSet(paused);
        morpho.setIsClaimRewardsPaused(paused);
        assertEq(morpho.isClaimRewardsPaused(), paused);
    }

    function testSetIsSupplyPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsSupplyPaused(underlying, paused);
    }

    function testSetIsSupplyPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsSupplyPaused(link, paused);
    }

    function testSetIsSupplyPaused(uint256 seed, bool paused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsSupplyPausedSet(underlying, paused);
        morpho.setIsSupplyPaused(underlying, paused);
        assertEq(morpho.market(underlying).pauseStatuses.isSupplyPaused, paused);
    }

    function testSetIsSupplyCollateralPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsSupplyCollateralPaused(underlying, paused);
    }

    function testSetIsSupplyCollateralPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsSupplyCollateralPaused(link, paused);
    }

    function testSetIsSupplyCollateralPaused(uint256 seed, bool paused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsSupplyCollateralPausedSet(underlying, paused);
        morpho.setIsSupplyCollateralPaused(underlying, paused);
        assertEq(morpho.market(underlying).pauseStatuses.isSupplyCollateralPaused, paused);
    }

    function testSetIsBorrowPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsBorrowPaused(underlying, paused);
    }

    function testSetIsBorrowPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsBorrowPaused(link, paused);
    }

    function testSetIsBorrowPaused(uint256 seed, bool paused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsBorrowPausedSet(underlying, paused);
        morpho.setIsBorrowPaused(underlying, paused);
        assertEq(morpho.market(underlying).pauseStatuses.isBorrowPaused, paused);
    }

    function testSetIsRepayPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsRepayPaused(underlying, paused);
    }

    function testSetIsRepayPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsRepayPaused(link, paused);
    }

    function testSetIsRepayPaused(uint256 seed, bool paused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsRepayPausedSet(underlying, paused);
        morpho.setIsRepayPaused(underlying, paused);
        assertEq(morpho.market(underlying).pauseStatuses.isRepayPaused, paused);
    }

    function testSetIsWithdrawPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsWithdrawPaused(underlying, paused);
    }

    function testSetIsWithdrawPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsWithdrawPaused(link, paused);
    }

    function testSetIsWithdrawPaused(uint256 seed, bool paused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsWithdrawPausedSet(underlying, paused);
        morpho.setIsWithdrawPaused(underlying, paused);
        assertEq(morpho.market(underlying).pauseStatuses.isWithdrawPaused, paused);
    }

    function testSetIsWithdrawCollateralPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsWithdrawCollateralPaused(underlying, paused);
    }

    function testSetIsWithdrawCollateralPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsWithdrawCollateralPaused(link, paused);
    }

    function testSetIsWithdrawCollateralPaused(uint256 seed, bool paused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsWithdrawCollateralPausedSet(underlying, paused);
        morpho.setIsWithdrawCollateralPaused(underlying, paused);
        assertEq(morpho.market(underlying).pauseStatuses.isWithdrawCollateralPaused, paused);
    }

    function testSetIsLiquidateCollateralPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsLiquidateCollateralPaused(underlying, paused);
    }

    function testSetIsLiquidateCollateralPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsLiquidateCollateralPaused(link, paused);
    }

    function testSetIsLiquidateCollateralPaused(uint256 seed, bool paused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsLiquidateCollateralPausedSet(underlying, paused);
        morpho.setIsLiquidateCollateralPaused(underlying, paused);
        assertEq(morpho.market(underlying).pauseStatuses.isLiquidateCollateralPaused, paused);
    }

    function testSetIsLiquidateBorrowPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsLiquidateBorrowPaused(underlying, paused);
    }

    function testSetIsLiquidateBorrowPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsLiquidateBorrowPaused(link, paused);
    }

    function testSetIsLiquidateBorrowPaused(uint256 seed, bool paused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsLiquidateBorrowPausedSet(underlying, paused);
        morpho.setIsLiquidateBorrowPaused(underlying, paused);
        assertEq(morpho.market(underlying).pauseStatuses.isLiquidateBorrowPaused, paused);
    }

    function testSetIsPausedFailsIfNotOwner(address underlying, bool paused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsPaused(underlying, paused);
    }

    function testSetIsPausedFailsIfMarketNotCreated(bool paused) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsPaused(link, paused);
    }

    function testSetIsPaused(uint256 seed, bool isPaused) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsSupplyPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsSupplyCollateralPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsRepayPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsWithdrawPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsWithdrawCollateralPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsLiquidateCollateralPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsLiquidateBorrowPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsBorrowPausedSet(underlying, isPaused);

        morpho.setIsPaused(underlying, isPaused);

        Types.PauseStatuses memory pauseStatuses = morpho.market(underlying).pauseStatuses;
        assertEq(pauseStatuses.isSupplyPaused, isPaused);
        assertEq(pauseStatuses.isSupplyCollateralPaused, isPaused);
        assertEq(pauseStatuses.isRepayPaused, isPaused);
        assertEq(pauseStatuses.isWithdrawPaused, isPaused);
        assertEq(pauseStatuses.isWithdrawCollateralPaused, isPaused);
        assertEq(pauseStatuses.isLiquidateCollateralPaused, isPaused);
        assertEq(pauseStatuses.isLiquidateBorrowPaused, isPaused);
        assertEq(pauseStatuses.isBorrowPaused, isPaused);
    }

    function testSetIsPausedDoesNotSetBorrowPauseIfDeprecated(uint256 seed, bool isPaused) public {
        address underlying = _randomUnderlying(seed);
        morpho.setIsBorrowPaused(underlying, true);
        morpho.setIsDeprecated(underlying, true);

        vm.expectEmit(true, true, true, true);
        emit Events.IsSupplyPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsSupplyCollateralPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsRepayPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsWithdrawPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsWithdrawCollateralPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsLiquidateCollateralPausedSet(underlying, isPaused);
        vm.expectEmit(true, true, true, true);
        emit Events.IsLiquidateBorrowPausedSet(underlying, isPaused);

        morpho.setIsPaused(underlying, isPaused);

        Types.PauseStatuses memory pauseStatuses = morpho.market(underlying).pauseStatuses;

        assertEq(pauseStatuses.isSupplyPaused, isPaused);
        assertEq(pauseStatuses.isSupplyCollateralPaused, isPaused);
        assertEq(pauseStatuses.isRepayPaused, isPaused);
        assertEq(pauseStatuses.isWithdrawPaused, isPaused);
        assertEq(pauseStatuses.isWithdrawCollateralPaused, isPaused);
        assertEq(pauseStatuses.isLiquidateCollateralPaused, isPaused);
        assertEq(pauseStatuses.isLiquidateBorrowPaused, isPaused);
        assertEq(pauseStatuses.isBorrowPaused, true);
    }

    function testSetIsPausedForAllMarketsFailsIfNotOwner(bool isPaused) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsPausedForAllMarkets(isPaused);
    }

    function testSetIsPausedForAllMarkets(bool isPaused) public {
        address[] memory markets = morpho.marketsCreated();

        for (uint256 i; i < markets.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit Events.IsSupplyPausedSet(markets[i], isPaused);
            vm.expectEmit(true, true, true, true);
            emit Events.IsSupplyCollateralPausedSet(markets[i], isPaused);
            vm.expectEmit(true, true, true, true);
            emit Events.IsRepayPausedSet(markets[i], isPaused);
            vm.expectEmit(true, true, true, true);
            emit Events.IsWithdrawPausedSet(markets[i], isPaused);
            vm.expectEmit(true, true, true, true);
            emit Events.IsWithdrawCollateralPausedSet(markets[i], isPaused);
            vm.expectEmit(true, true, true, true);
            emit Events.IsLiquidateCollateralPausedSet(markets[i], isPaused);
            vm.expectEmit(true, true, true, true);
            emit Events.IsLiquidateBorrowPausedSet(markets[i], isPaused);
            vm.expectEmit(true, true, true, true);
            emit Events.IsBorrowPausedSet(markets[i], isPaused);
        }

        morpho.setIsPausedForAllMarkets(isPaused);

        for (uint256 i; i < markets.length; i++) {
            Types.PauseStatuses memory pauseStatuses = morpho.market(markets[i]).pauseStatuses;
            assertEq(pauseStatuses.isSupplyPaused, isPaused);
            assertEq(pauseStatuses.isSupplyCollateralPaused, isPaused);
            assertEq(pauseStatuses.isRepayPaused, isPaused);
            assertEq(pauseStatuses.isWithdrawPaused, isPaused);
            assertEq(pauseStatuses.isWithdrawCollateralPaused, isPaused);
            assertEq(pauseStatuses.isLiquidateCollateralPaused, isPaused);
            assertEq(pauseStatuses.isLiquidateBorrowPaused, isPaused);
            assertEq(pauseStatuses.isBorrowPaused, isPaused);
        }
    }

    function testSetIsP2PDisabledFailsIfNotOwner(address underlying, bool disabled) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsP2PDisabled(underlying, disabled);
    }

    function testSetIsP2PDisabledFailsIfMarketNotCreated(bool disabled) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsP2PDisabled(link, disabled);
    }

    function testSetIsP2PDisabled(uint256 seed, bool disabled) public {
        address underlying = _randomUnderlying(seed);
        vm.expectEmit(true, true, true, true);
        emit Events.IsP2PDisabledSet(underlying, disabled);
        morpho.setIsP2PDisabled(underlying, disabled);
        assertEq(morpho.market(underlying).pauseStatuses.isP2PDisabled, disabled);
    }

    function testSetIsDeprecatedFailsIfNotOwner(address underlying, bool deprecated) public {
        vm.prank(DEFAULT_PRANKER);
        vm.expectRevert("Ownable: caller is not the owner");
        morpho.setIsDeprecated(underlying, deprecated);
    }

    function testSetIsDeprecatedFailsIfMarketNotCreated(bool deprecated) public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        morpho.setIsDeprecated(link, deprecated);
    }

    function testSetIsDeprecatedFailsIfBorrowNotPaused(uint256 seed, bool deprecated) public {
        address underlying = _randomUnderlying(seed);
        vm.expectRevert(Errors.BorrowNotPaused.selector);
        morpho.setIsDeprecated(underlying, deprecated);
    }

    function testSetIsDeprecated(uint256 seed, bool deprecated) public {
        address underlying = _randomUnderlying(seed);
        morpho.setIsBorrowPaused(underlying, true);
        vm.expectEmit(true, true, true, true);
        emit Events.IsDeprecatedSet(underlying, deprecated);
        morpho.setIsDeprecated(underlying, deprecated);
        assertEq(morpho.market(underlying).pauseStatuses.isDeprecated, deprecated);
    }

    function testShouldSetBorrowPaused(uint256 seed) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        morpho.setIsBorrowPaused(market.underlying, true);

        assertEq(morpho.market(market.underlying).pauseStatuses.isBorrowPaused, true);
    }

    function testShouldNotSetBorrowNotPausedWhenDeprecated(uint256 seed) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        morpho.setIsBorrowPaused(market.underlying, true);
        morpho.setIsDeprecated(market.underlying, true);

        vm.expectRevert(Errors.MarketIsDeprecated.selector);
        morpho.setIsBorrowPaused(market.underlying, false);
    }

    function testShouldSetDeprecatedWhenBorrowPaused(uint256 seed, bool isDeprecated) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        morpho.setIsBorrowPaused(market.underlying, true);

        morpho.setIsDeprecated(market.underlying, isDeprecated);

        assertEq(morpho.market(market.underlying).pauseStatuses.isDeprecated, isDeprecated);
    }

    function testShouldNotSetDeprecatedWhenBorrowNotPaused(uint256 seed, bool isDeprecated) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        morpho.setIsBorrowPaused(market.underlying, false);

        vm.expectRevert(Errors.BorrowNotPaused.selector);
        morpho.setIsDeprecated(market.underlying, isDeprecated);
    }

    function _containsUnderlying(address underlying) internal view returns (bool) {
        for (uint256 i; i < allUnderlyings.length; i++) {
            if (allUnderlyings[i] == underlying) {
                return true;
            }
        }
        return false;
    }
}
