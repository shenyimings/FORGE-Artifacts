// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Test} from "../../lib/forge-std/src/Test.sol";
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import {VBase} from "../../contracts/tokens/VBase.sol";
import {VQuote} from "../../contracts/tokens/VQuote.sol";
import {CurveCryptoViews} from "../../contracts/CurveCryptoViews.sol";
import "../../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../helpers/Parameters.EURUSD.sol";

contract CurvePoolTest is Deployment {
    event TokenExchange(
        address indexed buyer, uint256 sold_id, uint256 tokens_sold, uint256 bought_id, uint256 tokens_bought
    );
    event AddLiquidity(address indexed provider, uint256[2] token_amounts, uint256 fee, uint256 token_supply);
    event RemoveLiquidity(address indexed provider, uint256[2] token_amounts, uint256 token_supply);
    event Transfer(address indexed from, address indexed to, uint256 value);

    using LibMath for uint256;
    using LibMath for int256;

    /* accounts */
    address lpOne = address(123);
    address lpTwo = address(456);
    address traderOne = address(789);

    function setUp() public virtual override {
        vm.deal(lpOne, 100 ether);
        vm.deal(lpTwo, 100 ether);
        vm.deal(traderOne, 100 ether);

        super.setUp();
    }

    function _dealAndApprove(address account, address spender, uint256 quoteAmount)
        internal
        returns (uint256 baseAmount)
    {
        // deal quote and base tokens
        baseAmount = quoteAmount.wadDiv(cryptoSwap.price_oracle());
        deal(address(vQuote), account, quoteAmount);
        deal(address(vBase), account, baseAmount);

        // approve quote and base tokens
        vm.startPrank(account);
        vQuote.approve(spender, quoteAmount);
        vm.stopPrank();
        vm.startPrank(account);
        vBase.approve(spender, baseAmount);
        vm.stopPrank();
    }

    function _calcRemoveLiquidity(uint256 amount, uint256[2] memory min_amounts)
        internal
        returns (uint256[2] memory amountReturned, uint256[2] memory amountRemaining)
    {
        uint256[2] memory balances = [cryptoSwap.balances(0), cryptoSwap.balances(1)];
        uint256 totalSupply = lpToken.totalSupply();

        for (uint256 i = 0; i < 2; i++) {
            uint256 d_balance = ((amount - 1) * balances[i]) / totalSupply;
            assertTrue(d_balance >= min_amounts[i]);
            amountReturned[i] = d_balance;
            amountRemaining[i] = balances[i] - d_balance;
        }
    }

    function _dealAndProvideLiquidity(address account, uint256 quoteAmount, uint256 baseAmount) internal {
        // deal quote and base tokens
        deal(address(vQuote), account, quoteAmount);
        deal(address(vBase), account, baseAmount);

        // approve quote and base tokens
        vm.startPrank(account);
        vQuote.approve(address(cryptoSwap), quoteAmount);
        vm.stopPrank();
        vm.startPrank(account);
        vBase.approve(address(cryptoSwap), baseAmount);
        vm.stopPrank();

        // provide liquidity
        vm.startPrank(account);
        cryptoSwap.add_liquidity([quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    // TEST SETUP

    function test_InitializeParamsCorrectly() public {
        // check that the curve pool is initialized correctly
        (, int256 answer,,,) = baseOracle.latestRoundData();
        uint8 decimals = baseOracle.decimals();
        uint256 initialPrice = answer.toUint256() * (10 ** (18 - decimals));
        assertEq(cryptoSwap.coins(0), address(vQuote));
        assertEq(cryptoSwap.coins(1), address(vBase));
        assertEq(lpToken.minter(), address(cryptoSwap));
        assertEq(cryptoSwap.token(), address(lpToken));
        assertEq(cryptoSwap.A(), EURUSD.A);
        assertEq(cryptoSwap.gamma(), EURUSD.gamma);
        assertEq(cryptoSwap.mid_fee(), EURUSD.mid_fee);
        assertEq(cryptoSwap.out_fee(), EURUSD.out_fee);
        assertEq(cryptoSwap.allowed_extra_profit(), EURUSD.allowed_extra_profit);
        assertEq(cryptoSwap.fee_gamma(), EURUSD.fee_gamma);
        assertEq(cryptoSwap.adjustment_step(), EURUSD.adjustment_step);
        assertEq(cryptoSwap.admin_fee(), EURUSD.admin_fee);
        assertEq(cryptoSwap.ma_half_time(), EURUSD.ma_half_time);
        assertEq(cryptoSwap.price_scale(), initialPrice);
        assertEq(cryptoSwap.price_oracle(), initialPrice);
        assertEq(cryptoSwap.last_prices(), initialPrice);
    }

    function test_dealAndApprove(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);
        uint256 baseAmount = _dealAndApprove(lpOne, address(cryptoSwap), quoteAmount);

        assertEq(vQuote.balanceOf(lpOne), quoteAmount);
        assertEq(vQuote.allowance(lpOne, address(cryptoSwap)), quoteAmount);
        assertEq(vBase.balanceOf(lpOne), baseAmount);
        assertEq(vBase.allowance(lpOne, address(cryptoSwap)), baseAmount);
    }

    // LIQUIDITY

    function test_FuzzCanProvideLiquidity(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);
        uint256 baseAmount = _dealAndApprove(lpOne, address(cryptoSwap), quoteAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(lpOne, address(cryptoSwap), quoteAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(lpOne, address(cryptoSwap), baseAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), lpOne, 0 /* unkown until totalSupply > 0 */ );
        vm.expectEmit(true, true, true, false);
        emit AddLiquidity(lpOne, [quoteAmount, baseAmount], 0, 0);

        vm.startPrank(lpOne);
        cryptoSwap.add_liquidity([quoteAmount, baseAmount], 0);
        vm.stopPrank();

        assertEq(cryptoSwap.balances(0), quoteAmount);
        assertEq(cryptoSwap.balances(1), baseAmount);
        assertEq(vQuote.balanceOf(address(cryptoSwap)), quoteAmount);
        assertEq(vBase.balanceOf(address(cryptoSwap)), baseAmount);
        assertTrue(lpToken.balanceOf(lpOne) > cryptoSwap.calc_token_amount([quoteAmount, baseAmount]));
    }

    function testFail_ProvideZeroLiquidity() public {
        cryptoSwap.add_liquidity([uint256(0), uint256(0)], 0);
    }

    function testFuzz_CanWithdrawLiquidity(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);
        uint256 baseAmount = _dealAndApprove(lpOne, address(cryptoSwap), quoteAmount);

        vm.startPrank(lpOne);
        cryptoSwap.add_liquidity([quoteAmount, baseAmount], 0);
        vm.stopPrank();

        uint256 lpTokenAmount = lpToken.balanceOf(lpOne);
        assertTrue(lpTokenAmount > 0);

        (, uint256[2] memory dust) = _calcRemoveLiquidity(lpTokenAmount, [uint256(0), uint256(0)]);

        assertEq(dust[0], 2);
        assertEq(dust[1], 1);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(lpOne, address(0), lpTokenAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), lpOne, quoteAmount - dust[0]);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), lpOne, baseAmount - dust[1]);
        vm.expectEmit(true, true, true, false, address(cryptoSwap));
        emit RemoveLiquidity(lpOne, [quoteAmount - dust[0], baseAmount - dust[1]], 0);

        vm.startPrank(lpOne);
        cryptoSwap.remove_liquidity(lpTokenAmount, [uint256(0), uint256(0)]);
        vm.stopPrank();
    }

    function testFail_WithdrawZeroLiquidity(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);
        uint256 baseAmount = _dealAndApprove(lpOne, address(cryptoSwap), quoteAmount);

        vm.startPrank(lpOne);
        cryptoSwap.add_liquidity([quoteAmount, baseAmount], 0);
        vm.stopPrank();

        uint256 lpTokenAmount = lpToken.balanceOf(lpOne);
        assertTrue(lpTokenAmount > 0);

        cryptoSwap.remove_liquidity(0, [uint256(0), uint256(0)]);
    }

    function testFuzz_CanDepositLiquidityTwice(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);

        uint256 firstQuoteAmount = quoteAmount / 2;
        uint256 secondQuoteAmount = quoteAmount - firstQuoteAmount;

        /* FIRST DEPOSIT */

        uint256 firstBaseAmount = _dealAndApprove(lpOne, address(cryptoSwap), firstQuoteAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(lpOne, address(cryptoSwap), firstQuoteAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(lpOne, address(cryptoSwap), firstBaseAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), lpOne, 0 /* unkown until totalSupply > 0 */ );
        vm.expectEmit(true, true, true, false);
        emit AddLiquidity(lpOne, [firstQuoteAmount, firstBaseAmount], 0, 0);

        vm.startPrank(lpOne);
        cryptoSwap.add_liquidity([firstQuoteAmount, firstBaseAmount], 0);
        vm.stopPrank();

        /* SECOND DEPOSIT */

        uint256 secondBaseAmount = _dealAndApprove(lpOne, address(cryptoSwap), secondQuoteAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(lpOne, address(cryptoSwap), secondQuoteAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(lpOne, address(cryptoSwap), secondBaseAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), lpOne, 0 /* unkown until totalSupply > 0 */ );
        vm.expectEmit(true, true, true, false);
        emit AddLiquidity(lpOne, [secondQuoteAmount, secondBaseAmount], 0, 0);

        vm.startPrank(lpOne);
        cryptoSwap.add_liquidity([secondQuoteAmount, secondBaseAmount], 0);
        vm.stopPrank();

        /* ASSERTIONS */

        assertEq(cryptoSwap.balances(0), firstQuoteAmount + secondQuoteAmount);
        assertEq(cryptoSwap.balances(1), firstBaseAmount + secondBaseAmount);
        assertEq(vQuote.balanceOf(address(cryptoSwap)), firstQuoteAmount + secondQuoteAmount);
        assertEq(vBase.balanceOf(address(cryptoSwap)), firstBaseAmount + secondBaseAmount);
    }

    function testFuzz_ProvideLiquidityInUnevenRatios(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);
        uint256 baseAmount;

        // at price_oracle ratio
        baseAmount = quoteAmount.wadDiv(cryptoSwap.price_oracle());
        _dealAndProvideLiquidity(lpOne, quoteAmount, baseAmount);

        // at price_scale ratio
        baseAmount = quoteAmount.wadDiv(cryptoSwap.price_scale());
        _dealAndProvideLiquidity(lpOne, quoteAmount, baseAmount);

        // at balances ratio
        baseAmount = quoteAmount.wadDiv(cryptoSwap.balances(0).wadDiv(cryptoSwap.balances(1)));
        _dealAndProvideLiquidity(lpOne, quoteAmount, baseAmount);

        // all quote
        _dealAndProvideLiquidity(lpOne, quoteAmount, 0);

        // all base
        _dealAndProvideLiquidity(lpOne, 0, baseAmount);
    }

    // TRADING

    function testFuzz_callDyOnQuoteToken(uint256 dx) public {
        vm.assume(dx > 1 ether && dx < type(uint64).max);

        // provide enough liquidity
        uint256 lpQuoteAmount = dx * 5;
        _dealAndProvideLiquidity(lpOne, lpQuoteAmount, lpQuoteAmount.wadDiv(cryptoSwap.price_oracle()));

        vm.startPrank(traderOne);
        cryptoSwap.get_dy(0, 1, dx);
        vm.stopPrank();
    }

    function testFuzz_callDyOnBaseToken(uint256 dx) public {
        vm.assume(dx > 1 ether && dx < type(uint64).max);

        // provide enough liquidity
        uint256 lpQuoteAmount = dx * 5;
        _dealAndProvideLiquidity(lpOne, lpQuoteAmount, lpQuoteAmount.wadDiv(cryptoSwap.price_oracle()));

        cryptoSwap.get_dy(1, 0, dx);
    }

    function testFuzz_ExchangeQuoteForBase(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);

        // provide enough liquidity
        uint256 lpQuoteAmount = quoteAmount * 5;
        _dealAndProvideLiquidity(lpOne, lpQuoteAmount, lpQuoteAmount.wadDiv(cryptoSwap.price_oracle()));

        _dealAndApprove(traderOne, address(cryptoSwap), quoteAmount);

        uint256 vBaseBalanceBefore = vBase.balanceOf(traderOne);
        uint256 dy = cryptoSwap.get_dy(0, 1, quoteAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(traderOne, address(cryptoSwap), quoteAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), traderOne, dy);
        vm.expectEmit(true, true, true, false);
        emit TokenExchange(traderOne, 0, quoteAmount, 1, dy);

        vm.startPrank(traderOne);
        cryptoSwap.exchange(0, 1, quoteAmount, 0);
        vm.stopPrank();

        assertEq(vQuote.balanceOf(traderOne), 0);
        assertEq(vBase.balanceOf(traderOne), dy + vBaseBalanceBefore);
    }

    function testFuzz_ExchangeBaseForQuote(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);

        // provide enough liquidity
        uint256 lpQuoteAmount = quoteAmount * 5;
        _dealAndProvideLiquidity(lpOne, lpQuoteAmount, lpQuoteAmount.wadDiv(cryptoSwap.price_oracle()));

        uint256 baseAmount = _dealAndApprove(traderOne, address(cryptoSwap), quoteAmount);

        uint256 vQuoteBalanceBefore = vQuote.balanceOf(traderOne);
        uint256 dy = cryptoSwap.get_dy(1, 0, baseAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(traderOne, address(cryptoSwap), baseAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), traderOne, dy);
        vm.expectEmit(true, true, true, false);
        emit TokenExchange(traderOne, 1, baseAmount, 0, dy);

        vm.startPrank(traderOne);
        cryptoSwap.exchange(1, 0, baseAmount, 0);
        vm.stopPrank();

        assertEq(vQuote.balanceOf(traderOne), dy + vQuoteBalanceBefore);
        assertEq(vBase.balanceOf(traderOne), 0);
    }

    // TODO: Exact Output Swaps

    function testFuzz_ExchangeQuoteForBaseTwice(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);

        // provide enough liquidity
        uint256 lpQuoteAmount = quoteAmount * 5;
        _dealAndProvideLiquidity(lpOne, lpQuoteAmount, lpQuoteAmount.wadDiv(cryptoSwap.price_oracle()));

        uint256 firstQuoteAmount = quoteAmount / 2;
        uint256 secondQuoteAmount = quoteAmount - firstQuoteAmount;

        // FIRST TRADE

        _dealAndApprove(traderOne, address(cryptoSwap), firstQuoteAmount);

        uint256 vBaseBalanceBefore = vBase.balanceOf(traderOne);
        uint256 dy = cryptoSwap.get_dy(0, 1, firstQuoteAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(traderOne, address(cryptoSwap), firstQuoteAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), traderOne, dy);
        vm.expectEmit(true, true, true, false);
        emit TokenExchange(traderOne, 0, firstQuoteAmount, 1, dy);

        vm.startPrank(traderOne);
        cryptoSwap.exchange(0, 1, firstQuoteAmount, 0);
        vm.stopPrank();

        assertEq(vQuote.balanceOf(traderOne), 0);
        assertEq(vBase.balanceOf(traderOne), dy + vBaseBalanceBefore);

        // SECOND TRADE

        _dealAndApprove(traderOne, address(cryptoSwap), secondQuoteAmount);

        vBaseBalanceBefore = vBase.balanceOf(traderOne);
        dy = cryptoSwap.get_dy(0, 1, secondQuoteAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(traderOne, address(cryptoSwap), secondQuoteAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), traderOne, dy);
        vm.expectEmit(true, true, true, false);
        emit TokenExchange(traderOne, 0, secondQuoteAmount, 1, dy);

        vm.startPrank(traderOne);
        cryptoSwap.exchange(0, 1, secondQuoteAmount, 0);
        vm.stopPrank();

        assertEq(vBase.balanceOf(traderOne), dy + vBaseBalanceBefore);
        assertEq(vQuote.balanceOf(traderOne), 0);
    }

    // LIQUIDITY + TRADING

    function testFuzz_ProvideLiquidityAfterTrading(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);

        // provide enough liquidity

        uint256 lpQuoteAmount = quoteAmount * 5;
        _dealAndProvideLiquidity(lpOne, lpQuoteAmount, lpQuoteAmount.wadDiv(cryptoSwap.price_oracle()));

        // trade quote for base

        _dealAndApprove(traderOne, address(cryptoSwap), quoteAmount);
        uint256 vBaseBalanceBefore = vBase.balanceOf(traderOne);
        uint256 dy = cryptoSwap.get_dy(0, 1, quoteAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(traderOne, address(cryptoSwap), quoteAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), traderOne, dy);
        vm.expectEmit(true, true, true, false);
        emit TokenExchange(traderOne, 0, quoteAmount, 1, dy);

        vm.startPrank(traderOne);
        cryptoSwap.exchange(0, 1, quoteAmount, 0);
        vm.stopPrank();

        assertEq(vQuote.balanceOf(traderOne), 0);
        assertEq(vBase.balanceOf(traderOne), dy + vBaseBalanceBefore);

        // provide liquidity

        _dealAndProvideLiquidity(lpTwo, lpQuoteAmount, lpQuoteAmount.wadDiv(cryptoSwap.price_oracle()));
    }

    function testFuzz_WithdrawLiquidityAfterTrading(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1 ether && quoteAmount < type(uint64).max);

        // provide enough liquidity

        uint256 lpQuoteAmount = quoteAmount * 5;
        uint256 lpBaseAmount = lpQuoteAmount.wadDiv(cryptoSwap.price_oracle());
        _dealAndProvideLiquidity(lpOne, lpQuoteAmount, lpBaseAmount);

        // trade quote for base

        _dealAndApprove(traderOne, address(cryptoSwap), quoteAmount);
        uint256 vBaseBalanceBefore = vBase.balanceOf(traderOne);
        uint256 dy = cryptoSwap.get_dy(0, 1, quoteAmount);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(traderOne, address(cryptoSwap), quoteAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), traderOne, dy);
        vm.expectEmit(true, true, true, false);
        emit TokenExchange(traderOne, 0, quoteAmount, 1, dy);

        vm.startPrank(traderOne);
        cryptoSwap.exchange(0, 1, quoteAmount, 0);
        vm.stopPrank();

        assertEq(vQuote.balanceOf(traderOne), 0);
        assertEq(vBase.balanceOf(traderOne), dy + vBaseBalanceBefore);

        // remove liquidity

        uint256 lpTokenAmount = lpToken.balanceOf(lpOne);

        (, uint256[2] memory dust) = _calcRemoveLiquidity(lpTokenAmount, [uint256(0), uint256(0)]);

        assertEq(dust[0], 2);
        assertEq(dust[1], 1);

        // expect events
        vm.expectEmit(true, true, true, false);
        emit Transfer(lpOne, address(0), lpTokenAmount);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), lpOne, lpQuoteAmount - dust[0]);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(cryptoSwap), lpOne, lpBaseAmount - dust[1]);
        vm.expectEmit(true, true, true, false, address(cryptoSwap));
        emit RemoveLiquidity(lpOne, [lpQuoteAmount - dust[0], lpBaseAmount - dust[1]], 0);

        vm.startPrank(lpOne);
        cryptoSwap.remove_liquidity(lpTokenAmount, [uint256(0), uint256(0)]);
        vm.stopPrank();
    }

    // TODO: add tests for estimating outputs

    // CURVE VIEWS

    function testFuzz_ApproximateGetDx(uint256 tradeAmount) public {
        vm.assume(tradeAmount > 1 ether && tradeAmount < type(uint64).max);

        // provide liquidity
        uint256 lpQuoteAmount = tradeAmount * 5;
        uint256 lpBaseAmount = lpQuoteAmount.wadDiv(cryptoSwap.price_oracle());
        _dealAndProvideLiquidity(lpOne, lpQuoteAmount, lpBaseAmount);

        uint256 dx_ex_fees = curveCryptoViews.get_dx_ex_fees(cryptoSwap, 1, 0, tradeAmount);

        uint256 dy_ex_fees = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, 1, 0, dx_ex_fees);

        assertTrue((dy_ex_fees.toInt256() - tradeAmount.toInt256()).abs() < 0.1 ether); // 10% error
    }
}
