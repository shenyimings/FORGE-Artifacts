pragma solidity 0.6.7;

import "./GebUniswapV3ManagerBaseTest.t.sol";
import "../GebUniswapV3LiquidityManager.sol";

contract GebUniswapV3LiquidityManagerTest is GebUniswapV3ManagerBaseTest {
    uint256 threshold = 200040; //~20%
    uint256 delay     = 120 minutes;

    GebUniswapV3LiquidityManager manager;

    // --- Test Setup ---
    function setUp() override public {
        super.setUp();
        manager = new GebUniswapV3LiquidityManager("Geb-Uniswap-Manager", "GUM", address(testRai), threshold, delay, address(pool), oracle, pv, address(0));
        manager_base = GebUniswapV3ManagerBase(manager);

        // Will initialize the pool with the current price
        initialPoolPrice = helper_getRebalancePrice();
        pool.initialize(initialPoolPrice);

        u1 = new PoolUser(manager, pool, testRai, testWeth);
        u2 = new PoolUser(manager, pool, testRai, testWeth);
        u3 = new PoolUser(manager, pool, testRai, testWeth);
        u4 = new PoolUser(manager, pool, testRai, testWeth);

        users[0] = u1;
        users[1] = u2;
        users[2] = u3;
        users[3] = u4;

        helper_transferToAdds(users);
        helper_addWhaleLiquidity();
    }

    // --- Helper ---
    function helper_addLiquidity(uint8 user) public {
        PoolUser u = users[(user - 1) % 4];
        uint256 token0Amount = 3000 ether;
        uint256 token1Amount = 3000 ether;

        u.doApprove(address(testRai), address(manager), token0Amount);
        u.doApprove(address(testWeth), address(manager), token1Amount);

        (, , , ,uint256 threshold_,,) = manager.position();
        (int24 newLower, int24 newUpper, ) = manager.getNextTicks(threshold_);

        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint128 liq = helper_getLiquidityAmountsForTicks(sqrtRatioX96, newLower, newUpper, token0Amount, token1Amount);
        u.doDeposit(liq);
    }
 
    // --- Test Sanity Variables ---
    function test_sanity_uint_variables() public {
        uint256 _delay = manager.delay();
        assertTrue(_delay == delay);

        (,,,,uint256 _threshold,, )= manager.position();
        assertTrue(_threshold == threshold);
    }

    function test_sanity_variables_address() public {
        address token0_ = manager.token0();
        assertTrue(token0_ == address(testRai) || token0_ == address(testWeth));

        address token1_ = manager.token1();
        assertTrue(token1_ == address(testRai) || token1_ == address(testWeth));

        address pool_ = address(manager.pool());
        assertTrue(pool_ == address(pool));

        address relayer_ = address(manager.oracle());
        assertTrue(relayer_ == address(oracle));
    }

    function test_sanity_pool() public {
        address token0_ = pool.token0();
        assertTrue(token0_ == address(token0));

        address token1_ = pool.token1();
        assertTrue(token1_ == address(token1));

        (uint160 poolPrice_, , , , , , ) = pool.slot0();
        assertTrue(poolPrice_ == initialPoolPrice);
    }

    // --- Test Modify Parameters ---
    function test_modify_delay() public {
        uint256 newDelay = 340 minutes;
        manager.modifyParameters(bytes32("delay"), newDelay);
        assertTrue(manager.delay() == newDelay);
    }

    function testFail_invalid_delay() public {
        uint256 newDelay = 20 days;
        manager.modifyParameters(bytes32("delay"), newDelay);
    }

    function test_modify_oracle() public {
        address newOracle = address(new OracleLikeMock());
        manager.modifyParameters(bytes32("oracle"), newOracle);
        assertTrue(address(manager.oracle()) == newOracle);
    }

    function testFail_modify_invalid_oracle() public {
        address newOracle = address(0x4);
        manager.modifyParameters(bytes32("oracle"), newOracle);
    }

    function testFail_thirdyParty_changingParameter() public {
        bytes memory data = abi.encodeWithSignature("modifyParameters(bytes32,uint256)", bytes32("delay"), 3605);
        u1.doArbitrary(address(manager_base), data);
    }

    function testFail_thirdyParty_changingOracle() public {
        bytes memory data = abi.encodeWithSignature("modifyParameters(bytes32,address)", bytes32("oracle"), address(4));
        u1.doArbitrary(address(manager_base), data);
    }

    // --- Test Getters ---
    function test_get_prices() public {
        (uint256 redemptionPrice, uint256 tokenPrice) = manager.getPrices();
        assertTrue(redemptionPrice == 3000000000000000000000000000);
        assertTrue(tokenPrice == 4000000000000000000000000000000);
    }

    function test_get_next_ticks() public {
        (,,,,uint256 __threshold,,) = manager.position();
        (int24 _nextLowerTick, int24 _nextUpperTick,) = manager.getNextTicks(__threshold);
        helper_logTick(_nextLowerTick);
        helper_logTick(_nextUpperTick);
        assertTrue(_nextLowerTick >= -887220 && _nextLowerTick <= _nextUpperTick);
        assertTrue(_nextUpperTick >= _nextLowerTick && _nextUpperTick <= 887220);
    }

    function test_get_token0_from_liquidity() public {
        helper_addLiquidity(1);
        helper_addLiquidity(2);
        uint128 liq = uint128(manager.balanceOf(address(u2)));

        uint256 tkn0Amt = manager.getToken0FromLiquidity(liq);

        (uint256 amount0, ) = u2.doWithdraw(liq);

        emit log_named_uint("tkn0Amt", tkn0Amt);
        emit log_named_uint("amount0", amount0);
        assertTrue(tkn0Amt == amount0);
    }

    function test_get_token1_from_liquidity() public {
        helper_addLiquidity(1);
        helper_addLiquidity(2);
        uint128 liq = uint128(manager.balanceOf(address(u2)));

        uint256 tkn1Amt = manager.getToken1FromLiquidity(liq);

        (, uint256 amount1) = u2.doWithdraw(liq);

        emit log_named_uint("tkn1Amt", tkn1Amt);
        emit log_named_uint("amount1", amount1);
        assertTrue(tkn1Amt == amount1);
    }

        function test_getNextTicks_return_correctly() public {
        helper_addLiquidity(1); // Starting with a bit of liquidity
        helper_addLiquidity(2); // Starting with a bit of liquidity
        helper_addLiquidity(3); // Starting with a bit of liquidity

        testRai.approve(address(manager), 10);
        testWeth.approve(address(manager), 10);
        hevm.warp(2 days); // Advance to the future

        helper_changeRedemptionPrice(2500000000 ether);
        (,,,,uint256 __threshold,,) = manager.position();
        (int24 lower, int24 upper, int24 price) = manager.getNextTicks(__threshold);

        manager.rebalance();

        (bytes32 end_id, int24 end_lowerTick, int24 end_upperTick, uint128 end_uniLiquidity,,,) = manager.position();
        assertTrue(lower == end_lowerTick);
        assertTrue(upper == end_upperTick);
    }

    function test_getter_return_correct_amount() public {
        helper_addLiquidity(1); //Starting with a bit of liquidity

        uint256 balance_u1 = manager.balanceOf(address(u1));

        (uint256 amount0, uint256 amount1) = manager.getTokenAmountsFromLiquidity(uint128(balance_u1));

        (uint256 ac_amount0, uint256 ac_amount1) = u1.doWithdraw(uint128(balance_u1));

        assertTrue(amount0 == ac_amount0);
        assertTrue(amount1 == ac_amount1);
    }

    // --- Test Basic Functions ---
    function test_adding_liquidity() public {
        uint256 token0Amt = 10 ether;
        uint256 token1Amt = 10 ether;

        u1.doApprove(address(testRai), address(manager), token0Amt);
        u1.doApprove(address(testWeth), address(manager), token1Amt);

        (uint160 price1,int24 poolTick , , , , , ) = pool.slot0();
        helper_logTick(poolTick);
        (,,,,uint256 __threshold,,) = manager.position();
        (int24 newLower, int24 newUpper, ) = manager.getNextTicks(__threshold);

        uint128 liq = helper_getLiquidityAmountsForTicks(price1, newLower, newUpper, token0Amt, token1Amt);

        uint256 bal0Before = token0.balanceOf(address(u1));
        uint256 bal1Before = token1.balanceOf(address(u1));

        u1.doDeposit(liq);

        uint256 bal0After = token0.balanceOf(address(u1));
        uint256 bal1After = token1.balanceOf(address(u1));


        assertTrue(bal0Before > bal0After);
        assertTrue(bal1Before > bal1After);


        (bytes32 id, , , uint128 uniLiquidity,,,) = manager.position();
        (uint128 _liquidity, , , , ) = pool.positions(id);
        assertTrue(uniLiquidity == _liquidity);

        uint256 liquidityReceived = manager.totalSupply();
        assertTrue(liquidityReceived == liq);

        uint256 liqReceived = manager.balanceOf(address(u1));
        assertTrue(liqReceived == liq);
    }

    function testFail_adding_zero_liquidity() public {
        u2.doDeposit(0);
    }

    function test_rebalancing_pool() public {
        // Start with little liquidity
        helper_addLiquidity(1);

        testRai.approve(address(manager), 10);
        testWeth.approve(address(manager), 10);

        (bytes32 init_id, int24 init_lowerTick, int24 init_upperTick, uint128 init_uniLiquidity,,,) = manager.position();
        hevm.warp(2 days); // Advance to the future

        helper_changeRedemptionPrice(2500000000 ether); // Making RAI cheaper

        (,,,,uint256 __threshold,,) = manager.position();
        (int24 newLower, int24 newUpper, ) = manager.getNextTicks(__threshold);

        emit log_named_uint("r", 77);

        // The lower bound might still be the same, since it's currently the MIN_TICK
        assertTrue(init_lowerTick != newLower);
        assertTrue(init_upperTick != newUpper);

        manager.rebalance();
        emit log_named_uint("k", 99);

        (uint128 _liquidity, , , , ) = pool.positions(init_id);
        assertTrue(_liquidity == 0); //We should have burned the whole old position

        (, int24 end_lowerTick, int24 end_upperTick, uint128 end_uniLiquidity,,,) = manager.position();

        assertTrue(end_lowerTick == newLower);
        assertTrue(end_upperTick == newUpper);
    }

    function test_deposit_rebalance_withdraw() public {

        uint256 initBal0 = token0.balanceOf(address(u1));
        uint256 initBal1 = token1.balanceOf(address(u1));
        helper_addLiquidity(1);
        helper_addLiquidity(2);
        helper_addLiquidity(3);
        testRai.approve(address(manager), 10 ether);
        testWeth.approve(address(manager), 10 ether);

        helper_changeRedemptionPrice(3500000000 ether); // Making RAI cheaper
        hevm.warp(2 days); // Advance to the future
        manager.rebalance();
        (bytes32 id,,,,,,) = manager.position();
        (,,,uint256 zerOwned,uint256 oneOwed) = pool.positions(id);
        emit log_named_uint("zerOwned", zerOwned);
        emit log_named_uint("oneOwed", oneOwed);

        u1.doWithdraw(uint128(manager.balanceOf(address(u1))));
        uint256 finBal0 = token0.balanceOf(address(u1));
        uint256 finBal1 = token1.balanceOf(address(u1));
        (,,, zerOwned, oneOwed) = pool.positions(id);
        emit log_named_uint("zerOwned", zerOwned);
        emit log_named_uint("oneOwed", oneOwed);


        emit log_named_uint("initBal0", initBal0);
        emit log_named_uint("initBal1", initBal1);
        emit log_named_uint("finBal0", finBal0);
        emit log_named_uint("finBal1", finBal1);
        // assertTrue(initBal0 < finBal0);
        // assertTrue(initBal1 > finBal1);
    }

    function testFail_early_rebalancing() public {
        hevm.warp(2 days);    // Advance to the future
        manager.rebalance();  // Should pass
        hevm.warp(2 minutes); // Advance to the future
        manager.rebalance();  // Should fail
    }

    function test_withdrawing_liquidity() public {
        helper_addLiquidity(1); // Starting with a bit of liquidity

        uint256 liq = manager.balanceOf(address(u1));
        (bytes32 inti_id, , , uint128 inti_uniLiquidity,,,) = manager.position();
        (uint128 _li, , , , ) = pool.positions(inti_id);

        assertTrue(liq == _li);
        // emit log_named_uint("liq", liq);
        // emit log_named_uint("liq", inti_uniLiquidity);
        // emit log_named_uint("_li", _li);

        // Withdraw half of the liquidity
        (uint256 bal0, uint256 bal1) = u1.doWithdraw(uint128(liq / 2));

        helper_assert_is_close(manager.balanceOf(address(u1)), liq / 2);

        (uint128 _li2, , , , ) = pool.positions(inti_id);
        emit log_named_uint("_li2", _li2);
        emit log_named_uint("_li / 2", _li / 2);
        helper_assert_is_close(_li2, _li / 2);

        (bytes32 end_id, , , uint128 end_uniLiquidity,,,) = manager.position();
        emit log_named_uint("inti_uniLiquidity", inti_uniLiquidity / 2);
        emit log_named_uint("end_uniLiquidity", end_uniLiquidity);
        helper_assert_is_close(end_uniLiquidity, inti_uniLiquidity / 2);
    }

    function testFail_withdrawing_zero_liq() public {
        helper_addLiquidity(3); //Starting with a bit of liquidity
        u3.doWithdraw(0);
    }

    function testFail_calling_uni_callback() public {
        manager.uniswapV3MintCallback(0, 0, "");
    }

    // function test_single_collecting_fees() public {
    //     (uint160 price0, int24 tick0, , , , , ) = pool.slot0();
    //     emit log_named_uint("price0", price0);
    //     helper_logTick(tick0);

    //     uint256 wethAmount = 1 ether;
    //     uint256 raiAmount = 10 ether;

    //     u2.doApprove(address(testRai), address(manager), raiAmount);
    //     u2.doApprove(address(testWeth), address(manager), wethAmount);

    //     (,,,,uint256 __threshold,,) = manager.position();
    //     (int24 newLower, int24 newUpper, ) = manager.getNextTicks(__threshold);

    //     uint128 liq = helper_getLiquidityAmountsForTicks(price0, newLower, newUpper, 1 ether, 10 ether);

    //     uint256 bal0w = testWeth.balanceOf(address(u2));
    //     uint256 bal0r = testRai.balanceOf(address(u2));
    //     u2.doDeposit(liq);

    //     helper_do_swap();

    //     u2.doWithdraw(liq);

    //     uint256 bal1w = testWeth.balanceOf(address(u2));
    //     uint256 bal1r = testRai.balanceOf(address(u2));
    //     emit log_named_uint("bal0w", bal0w);
    //     emit log_named_uint("bal0r", bal0r);
    //     emit log_named_uint("bal1w", bal1w);
    //     emit log_named_uint("bal1r", bal1r);

    //     (uint160 price2,int24 tick2 , , , , , ) = pool.slot0();

    //     emit log_named_uint("price2", price2);
    //     helper_logTick(tick2);

    //     assertTrue(bal1r > bal0r);
    // }

    function test_multiple_users_depositing() public {
        helper_addLiquidity(1); // Starting with a bit of liquidity
        uint256 u1_balance = manager.balanceOf(address(u1));
        assert(u1_balance == manager.totalSupply());

        helper_addLiquidity(2); // Starting with a bit of liquidity
        uint256 u2_balance = manager.balanceOf(address(u2));
        assert(u1_balance + u2_balance == manager.totalSupply());

        helper_addLiquidity(3); // Starting with a bit of liquidity
        uint256 u3_balance = manager.balanceOf(address(u3));
        assert(u1_balance + u2_balance + u3_balance == manager.totalSupply());
    }

    function test_mint_transfer_and_burn() public {
        helper_addLiquidity(1); //Starting with a bit of liquidity
        u1.doTransfer(address(manager), address(u3), manager.balanceOf(address(u1)));
        u3.doWithdraw(uint128(manager.balanceOf(address(u3))));
    }

    function test_liquidty_proportional_to_balance() public {
        testRai.approve(address(manager), 10);
        testWeth.approve(address(manager), 10);
        helper_addLiquidity(1);

        // Make RAI twice more expensive
        helper_changeRedemptionPrice(6000000000 ether);

        // Another user adding liquidity
        helper_addLiquidity(2);

        // Return to the original price
        helper_changeRedemptionPrice(3000000000 ether);
        hevm.warp(2 days);

        manager.rebalance();

        uint256 bal1 = manager.balanceOf(address(u1));
        uint256 bal2 = manager.balanceOf(address(u2));

        assertTrue(bal1 != bal2);
        // (bytes32 id, , , uint128 uniLiquidity1,,,) = manager.position();
        // (uint128 _liquidity, , , , ) = pool.positions(id);
        emit log_named_uint("bal1", bal1);
        emit log_named_uint("bal2", bal2);

        // user should be able to withdraw their whole balance. Balance != Liquidity
        u1.doWithdraw(uint128(manager.balanceOf(address(u1))));
        u2.doWithdraw(uint128(manager.balanceOf(address(u2))));

        assertTrue(manager.totalSupply() == 0);
    }

    function test_multiple_users_adding_liquidity() public {
        uint256 u1_tkn0Amount = 5 ether;
        uint256 u1_tkn1Amount = 5 ether;

        u1.doApprove(address(testRai), address(manager), u1_tkn0Amount);
        u1.doApprove(address(testWeth), address(manager), u1_tkn1Amount);

        (bytes32 id, int24 init_lowerTick, int24 init_upperTick, uint128 uniLiquidity1,,,) = manager.position();
        (uint160 u1_sqrtRatioX96, , , , , , ) = pool.slot0();
        uint128 u1_liquidity = helper_getLiquidityAmountsForTicks(u1_sqrtRatioX96, init_lowerTick, init_upperTick, u1_tkn0Amount, u1_tkn1Amount);

        u1.doDeposit(u1_liquidity);

        // totalSupply should equal the sum of both liquidity amounts
        assertTrue(manager.totalSupply() == uniLiquidity1 + u1_liquidity);

        // Getting new pool information
        (, int24 mid_lowerTick, int24 mid_upperTick, uint128 mid_uniLiquidity,,,) = manager.position();
        assertTrue(mid_uniLiquidity == uniLiquidity1 + u1_liquidity);

        // Pool position shouldn't have changed
        assertTrue(init_lowerTick == mid_lowerTick);
        assertTrue(init_upperTick == mid_upperTick);

        // Make the redemption price higher
        helper_changeRedemptionPrice(3500000000 ether);

        uint256 u2_tkn0Amount = 5 ether;
        uint256 u2_tkn1Amount = 5 ether;

        u2.doApprove(address(testRai), address(manager), u2_tkn0Amount);
        u2.doApprove(address(testWeth), address(manager), u2_tkn1Amount);

        (,,,,uint256 __threshold,,) = manager.position();
        (int24 end_lowerTick, int24 end_upperTick, ) = manager.getNextTicks(__threshold);
        (uint160 u2_sqrtRatioX96, , , , , , ) = pool.slot0();
        uint128 u2_liquidity = helper_getLiquidityAmountsForTicks(u2_sqrtRatioX96, end_lowerTick, end_upperTick, u2_tkn0Amount, u2_tkn1Amount);

        u2.doDeposit(u2_liquidity);

        helper_logTick(mid_upperTick);
        helper_logTick(end_upperTick);
        // totalSupply should be equal to the sum of the liquidity amounts
        assertTrue(manager.totalSupply() == u1_liquidity + u2_liquidity);
        assertTrue(mid_lowerTick < end_lowerTick);
        assertTrue(mid_upperTick < end_upperTick);

    }

    function test_sqrt_conversion() public {
        // Using the Uniswap SDK to arrive at those numbers
        (uint256 redemptionPrice, uint256 ethUsdPrice) = manager.getPrices();

        uint160 sqrtRedPriceX96 = uint160(sqrt((ethUsdPrice * 2**96) / redemptionPrice));
        assertTrue(sqrtRedPriceX96 == 10278012941177838); // Value taken from Uniswap SDK
    }

    function testFail_try_minting_zero_liquidity() public {
        uint256 wethAmount = 1 ether;
        uint256 raiAmount = 10 ether;

        u1.doApprove(address(testRai), address(manager), raiAmount);
        u1.doApprove(address(testWeth), address(manager), wethAmount);

        emit log_named_uint("depositing", 0);
        u1.doDeposit(0);
    }

    function testFail_minting_largest_liquidity() public {
        uint256 wethAmount = 1 ether;
        uint256 raiAmount = 10 ether;

        u1.doApprove(address(testRai), address(manager), raiAmount);
        u1.doApprove(address(testWeth), address(manager), wethAmount);

        emit log_named_uint("depositing", 0);
        u1.doDeposit(uint128(0 - 1));
    }

    function testFail_burning_zero_liquidity() public {
        helper_addLiquidity(3);

        u3.doWithdraw(0);
    }

    function testFail_burning_more_than_owned_liquidity() public {
        helper_addLiquidity(3);

        u3.doWithdraw(uint128(0 - 1));
    }
}
