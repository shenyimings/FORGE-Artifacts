// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import {IPerpetual} from "../../contracts/interfaces/IPerpetual.sol";
import {IClearingHouse} from "../../contracts/interfaces/IClearingHouse.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../../contracts/lib/LibPerpetual.sol";

contract MultipleMarket is Deployment {
    // events
    event FundingRateUpdated(int256 cumulativeFundingRate, int256 cumulativeFundingPerLpToken, int256 fundingRate);

    // libraries
    using LibMath for int256;
    using LibMath for uint256;

    // addresses
    address lp = address(123);
    address user = address(456);

    // config values
    uint256 maxTradeAmount;
    uint256 minTradeAmount;

    function _dealAndDeposit(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);
        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
        vm.stopPrank();
    }

    function _dealAndProvideLiquidity(address addr, uint256 amount, uint256 market) internal {
        _dealAndDeposit(addr, amount);

        IPerpetual perp = clearingHouse.perpetuals(market);
        uint256 quoteAmount = amount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(perp.indexPrice().toUint256());
        vm.startPrank(addr);
        clearingHouse.provideLiquidity(market, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function setUp() public virtual override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition();
        minTradeAmount = clearingHouse.minPositiveOpenNotional();
    }

    function test_AddNewMarket() public {
        assertEq(clearingHouse.getNumMarkets(), 1);

        _deployEthMarket();

        assertEq(clearingHouse.getNumMarkets(), 2);
    }

    function test_UpdatingStateOnMultipleMarkets() public {
        _deployEthMarket();

        vm.warp(block.timestamp + 1);

        vm.expectEmit(true, true, true, true, address(perpetual));
        emit FundingRateUpdated(0, 0, 0);
        vm.expectEmit(true, true, true, true, address(eth_perpetual));
        emit FundingRateUpdated(0, 0, 0);
        clearingHouse.updateGlobalState();
    }

    function test_UpdateGlobalStateDoesntFailWhenOneMarketPaused() public {
        _deployEthMarket();

        vm.warp(block.timestamp + 1);

        // should emit twice, once for each market
        vm.expectEmit(true, true, true, true, address(perpetual));
        emit FundingRateUpdated(0, 0, 0);
        vm.expectEmit(true, true, true, true, address(eth_perpetual));
        emit FundingRateUpdated(0, 0, 0);
        clearingHouse.updateGlobalState();

        eth_perpetual.pause();

        vm.warp(block.timestamp + 1);

        // should emit once, for the non-paused market
        vm.expectEmit(true, true, true, true, address(perpetual));
        emit FundingRateUpdated(0, 0, 0);
        clearingHouse.updateGlobalState();
    }

    function test_SettleUserFundingPaymentsWhileOneMarketPaused() public {
        _deployEthMarket();

        vm.warp(block.timestamp + 1);

        // pause eth perpetual
        eth_perpetual.updateGlobalState();
        eth_perpetual.pause();

        // ensure paused
        vm.warp(block.timestamp + 1);
        vm.expectRevert(abi.encodePacked("Pausable: paused"));
        eth_perpetual.updateGlobalState();

        // shouldn't fail
        clearingHouse.__TestClearingHouse__settleUserFundingPayments(user);
    }

    function testFuzz_ExtendingPositionOnAnyMarketIncreasesInsuranceFund(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount);
        uint256 tradeAmount = depositAmount / 2;

        _deployEthMarket();

        _dealAndProvideLiquidity(lp, depositAmount, 0);
        _dealAndProvideLiquidity(lp, depositAmount, 1);
        _dealAndDeposit(user, depositAmount);

        assertEq(vault.getReserveValue(address(clearingHouse), false), 0);

        vm.startPrank(user);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        int256 insuranceFeeAfterEURTrade = vault.getReserveValue(address(clearingHouse), false);

        vm.startPrank(user);
        clearingHouse.changePosition(1, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        int256 insuranceFeeAfterETHTrade = vault.getReserveValue(address(clearingHouse), false);

        assertEq(insuranceFeeAfterEURTrade * 2, insuranceFeeAfterETHTrade);
    }

    function testFuzz_FailsToClosePositionAndWithdrawWithInsufficientMargin(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount);
        uint256 tradeAmount = depositAmount / 2;

        _deployEthMarket();

        _dealAndProvideLiquidity(lp, depositAmount, 0);
        _dealAndProvideLiquidity(lp, depositAmount, 1);
        _dealAndDeposit(user, depositAmount);

        vm.startPrank(user);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        vm.startPrank(user);
        clearingHouse.changePosition(1, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        uint256 proposedAmount = viewer.getTraderProposedAmount(0, user, 1e18, 100, 0);
        vm.expectRevert(IClearingHouse.ClearingHouse_WithdrawInsufficientMargin.selector);
        vm.startPrank(user);
        clearingHouse.closePositionWithdrawCollateral(0, proposedAmount, 0, ua);
        vm.stopPrank();
    }
}
