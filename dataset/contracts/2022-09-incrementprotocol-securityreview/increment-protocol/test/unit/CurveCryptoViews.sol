// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import {IClearingHouseViewer} from "../../contracts/interfaces/IClearingHouseViewer.sol";

// libraries
import {LibPerpetual} from "../../contracts/lib/LibPerpetual.sol";
import "../../contracts/lib/LibMath.sol";

contract CurveCryptoViews is Deployment {
    // addresses
    address lp = address(123);
    address trader = address(456);

    // config values
    uint256 maxTradeAmount;
    uint256 minTradeAmount;

    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    function setUp() public virtual override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition();
        minTradeAmount = clearingHouse.minPositiveOpenNotional();
    }

    function _dealAndDeposit(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);
        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
        vm.stopPrank();
    }

    function _dealAndProvideLiquidity(address addr, uint256 amount) internal {
        _dealAndDeposit(addr, amount);
        uint256 quoteAmount = amount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(addr);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function testFuzz_FailsToGetDyNoFeeDeductIfIEqJOrEitherOutOfRange(uint256 i, uint256 j, uint256 tradeAmount)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        if (i == j || i > 1 || j > 1) vm.expectRevert(abi.encodePacked("coin index out of range"));

        curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, i, j, tradeAmount);
    }

    function testFuzz_FailsToGetDyNoFeeDeductIfDxEqZero(uint256 i) public {
        i = bound(i, 0, 1);
        uint256 j = i == 0 ? 1 : 0;

        vm.expectRevert(abi.encodePacked("do not exchange 0 coins"));
        curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, i, j, 0);
    }

    function testFuzz_ReturnsValueForDyNoFeeDeductGTGetDy(uint256 i, uint256 tradeAmount, bool shouldRampGamma)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        i = bound(i, 0, 1);
        uint256 j = i == 0 ? 1 : 0;

        if (shouldRampGamma) {
            vm.mockCall(
                address(cryptoSwap), abi.encodeWithSelector(cryptoSwap.future_A_gamma_time.selector), abi.encode(1)
            );
        }

        uint256 dyNoFeeDeduct = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, i, j, tradeAmount);
        uint256 dy = curveCryptoViews.get_dy(cryptoSwap, i, j, tradeAmount);
        assertLt(dy, dyNoFeeDeduct);
    }

    function testFuzz_ReturnsValuesForGetDyNoFeeDeductAndGetDyFeesThatSumToGetDy(uint256 i, uint256 tradeAmount)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        i = bound(i, 0, 1);
        uint256 j = i == 0 ? 1 : 0;

        uint256 dyNoFeeDeduct = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, i, j, tradeAmount);
        uint256 dyFees = curveCryptoViews.get_dy_fees(cryptoSwap, i, j, tradeAmount);
        uint256 dy = curveCryptoViews.get_dy(cryptoSwap, i, j, tradeAmount);

        assertEq(dy, dyNoFeeDeduct - dyFees);
    }

    function testFuzz_ReturnsCorrectPercentageValueInFees(uint256 i, uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        i = bound(i, 0, 1);
        uint256 j = i == 0 ? 1 : 0;

        uint256 dy = cryptoSwap.get_dy(i, j, tradeAmount);
        uint256 dyNoFeeDeduct = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, i, j, tradeAmount);

        assertEq(
            (dyNoFeeDeduct - dy).wadDiv(dyNoFeeDeduct), curveCryptoViews.get_dy_fees_perc(cryptoSwap, i, j, tradeAmount)
        );
    }

    function testFuzz_FailsToGetDxExcludingFeesIfIEqJOrOutOfRange(uint256 i, uint256 j, uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 4);
        _dealAndProvideLiquidity(lp, tradeAmount * 4);

        if (i == j || i > 1 || j > 1) vm.expectRevert(abi.encodePacked("coin index out of range"));
        curveCryptoViews.get_dx_ex_fees(cryptoSwap, i, j, tradeAmount);
    }

    function testFuzz_FailsToGetDxExcludingFeesIfDxEqZero(uint256 i) public {
        i = bound(i, 0, 1);
        uint256 j = i == 0 ? 1 : 0;

        vm.expectRevert(abi.encodePacked("do not exchange 0 coins"));
        curveCryptoViews.get_dx_ex_fees(cryptoSwap, i, j, 0);
    }

    function testFuzz_ReturnsValueForGetDxExFeesGTDx(uint256 i, uint256 tradeAmount, bool shouldRampGamma) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 4);
        _dealAndProvideLiquidity(lp, tradeAmount * 4);

        i = bound(i, 0, 1);
        uint256 j = i == 0 ? 1 : 0;

        if (shouldRampGamma) {
            vm.mockCall(
                address(cryptoSwap), abi.encodeWithSelector(cryptoSwap.future_A_gamma_time.selector), abi.encode(1)
            );
        }

        uint256 dx = curveCryptoViews.get_dy(cryptoSwap, j, i, tradeAmount);
        uint256 dxExFees = curveCryptoViews.get_dx_ex_fees(cryptoSwap, i, j, tradeAmount);
        assertLt(dx, dxExFees);
    }
}
