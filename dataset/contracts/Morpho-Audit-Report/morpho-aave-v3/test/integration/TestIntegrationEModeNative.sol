// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IWETHGateway} from "src/interfaces/extensions/IWETHGateway.sol";

import {WETHGateway} from "src/extensions/WETHGateway.sol";

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationEModeNative is IntegrationTest {
    using PercentageMath for uint256;
    using TestMarketLib for TestMarket;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function setUp() public virtual override {
        DataTypes.ReserveConfigurationMap memory lsdConfig = pool.getConfiguration(stNative);

        eModeCategoryId = uint8(lsdConfig.getEModeCategory());

        super.setUp();
    }

    function testShouldLeverageLsdNative(uint256 seed, uint256 rawCollateral, address onBehalf, address receiver)
        public
    {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _assumeETHReceiver(receiver);
        _prepareOnBehalf(onBehalf);

        address lsdNative = _randomLsdNative(seed);

        TestMarket storage lsdNativeMarket = testMarkets[lsdNative];
        TestMarket storage wNativeMarket = testMarkets[wNative];

        rawCollateral = _boundCollateral(lsdNativeMarket, rawCollateral, wNativeMarket);
        uint256 borrowed = wNativeMarket.borrowable(lsdNativeMarket, rawCollateral, eModeCategoryId);

        user.approve(lsdNative, rawCollateral);
        user.supplyCollateral(lsdNative, rawCollateral, onBehalf);

        user.borrow(wNative, borrowed, onBehalf, receiver);

        user.withdrawCollateral(
            lsdNative,
            wNativeMarket.collateralized(lsdNativeMarket, rawCollateral, eModeCategoryId) - borrowed,
            onBehalf,
            receiver
        );
    }

    function testShouldNotLeverageNotLsdNative(
        uint256 seed,
        uint256 rawCollateral,
        uint256 borrowed,
        address onBehalf,
        address receiver
    ) public {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _assumeETHReceiver(receiver);
        _prepareOnBehalf(onBehalf);

        TestMarket storage wNativeMarket = testMarkets[wNative];

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(seed)];

        _assumeNotLsdNative(collateralMarket.underlying);
        vm.assume(collateralMarket.underlying != wNative);

        rawCollateral = _boundCollateral(collateralMarket, rawCollateral, wNativeMarket);
        borrowed = bound(
            borrowed,
            wNativeMarket.borrowable(collateralMarket, rawCollateral, 0).percentAdd(20),
            wNativeMarket.borrowable(collateralMarket, rawCollateral, collateralMarket.eModeCategoryId).percentAdd(20)
        );

        user.approve(collateralMarket.underlying, rawCollateral);
        user.supplyCollateral(collateralMarket.underlying, rawCollateral, onBehalf);

        vm.expectRevert(Errors.UnauthorizedBorrow.selector);
        user.borrow(wNative, borrowed, onBehalf, receiver);
    }

    function testShouldNotBorrowNotNative(uint256 seed, uint256 amount, address onBehalf, address receiver) public {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableNotInEMode(seed)];

        amount = _boundBorrow(market, amount);

        vm.expectRevert(Errors.InconsistentEMode.selector);
        user.borrow(market.underlying, amount, onBehalf, receiver);
    }
}
