pragma solidity ^0.6.7;

import "../GebUniswapV3TwoTrancheManager.sol";
import "./GebUniswapV3ManagerBaseTest.t.sol";

contract GebUniswapv3TwoTrancheManagerTest is GebUniswapV3ManagerBaseTest {
    GebUniswapV3TwoTrancheManager public manager;

    uint256 threshold1 = 200040; // 20%
    uint256 threshold2 = 50040;  // 5%
    uint128 ratio1 = 50;         // 36%
    uint128 ratio2 = 50;         // 36%
    uint256 delay = 120 minutes; // 10 minutes

    function setUp() override public {
        super.setUp();

        manager = new GebUniswapV3TwoTrancheManager("Geb-Uniswap-Manager", "GUM", address(testRai), uint128(delay), threshold1,threshold2, ratio1,ratio2, address(pool), oracle, pv, address(testWeth));
        manager_base = GebUniswapV3ManagerBase(manager);

        // Will initialize the pool with current price
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

        // Make the pool start with some spread out liquidity
        helper_addWhaleLiquidity();
    }

    function helper_addLiquidity(uint8 user) public {
        // (bytes32 i_id, , , uint128 i_uniLiquidity,,,) = manager.position();
        // (uint128 i_liquidity, , , , ) = pool.positions(i_id);
        PoolUser u = users[(user - 1) % 4];
        uint256 wethAmount = 3000 ether;
        uint256 raiAmount = 1000000 ether;

        u.doApprove(address(testRai), address(manager), raiAmount);
        u.doApprove(address(testWeth), address(manager), wethAmount);

        // (int24 newLower, int24 newUpper, ) = manager.getNextTicks(manager.getTargetTick());

        // (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        // uint128 liq = helper_getLiquidityAmountsForTicks(sqrtRatioX96, newLower, newUpper, wethAmount, raiAmount);
        u.doDeposit(100000000000000);
    }

    function test_sanity_uint_variables() public {
        uint256 _delay = manager.delay();
        assertTrue(_delay == delay);
    }

    function test_sanity_positions() public {
        (,,,,uint256 _threshold1,,) = manager.positions(0);
        assertTrue(_threshold1 == threshold1);
        uint256 _ratio1 = manager.ratio1();
        assertTrue(_ratio1 == ratio1);

        (,,,,uint256 _threshold2,,) = manager.positions(1);
        assertTrue(_threshold2 == threshold2);
        uint256 _ratio2 = manager.ratio2();
        assertTrue(_ratio2 == ratio2);
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

    function testFail_thirdyParty_changingOracle() public {
        bytes memory data = abi.encodeWithSignature("modifyParameters(bytes32,address)", bytes32("oracle"), address(4));
        u1.doArbitrary(address(manager), data);
    }

    function test_get_prices() public {
        (uint256 redemptionPrice, uint256 tokenPrice) = manager.getPrices();
        assertTrue(redemptionPrice == 3000000000 ether);
        assertTrue(tokenPrice == 4000000000000 ether);
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

    function test_get_token0_from_liquidity_burning() public {
        helper_addLiquidity(1);
        helper_addLiquidity(2);
        uint128 liq = uint128(manager.balanceOf(address(u2)));

        uint256 tkn0Amt = manager.getToken0FromLiquidity(liq);
        emit log_named_address("man", address(manager));

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

    function testFail_adding_zero_liquidity() public {
        u2.doDeposit(0);
    }

    function testFail_early_rebalancing() public {
        hevm.warp(2 days); //Advance to the future
        manager.rebalance(); // should pass
        hevm.warp(2 minutes); //Advance to the future
        manager.rebalance(); // should fail
    }

    function testFail_withdrawing_zero_liq() public {
        helper_addLiquidity(3); //Starting with a bit of liquidity
        u3.doWithdraw(0);
    }

    function testFail_calling_uni_callback() public {
        manager.uniswapV3MintCallback(0, 0, "");
    }


    function test_multiple_users_depositing() public {
        helper_addLiquidity(1); //Starting with a bit of liquidity
        uint256 u1_balance = manager.balanceOf(address(u1));
        assert(u1_balance == manager.totalSupply());

        helper_addLiquidity(2); //Starting with a bit of liquidity
        uint256 u2_balance = manager.balanceOf(address(u2));
        assert(u1_balance + u2_balance == manager.totalSupply());

        helper_addLiquidity(3); //Starting with a bit of liquidity
        uint256 u3_balance = manager.balanceOf(address(u3));
        assert(u1_balance + u2_balance + u3_balance == manager.totalSupply());
    }

    function test_mint_transfer_and_burn() public {
        helper_addLiquidity(1); //Starting with a bit of liquidity
        u1.doTransfer(address(manager), address(u3), manager.balanceOf(address(u1)));
        u3.doWithdraw(uint128(manager.balanceOf(address(u3))));
    }

    function test_mint_directly_with_eth() public {
        u1.doApprove(address(testRai), address(manager), 100000000000000 ether);
        u1.doDeposit{value: 10 ether}(1000);
    }

    function test_refund_eth() public {
        uint256 initBal = address(u1).balance;
        u1.doApprove(address(testRai), address(manager), 100000000000000 ether);
        u1.doDeposit{value: 10 ether}(1000);
        uint256 finBal = address(u1).balance;
        assert(initBal - finBal > 10);
    }

    function testFail_slippage_check() public {
        u1.doApprove(address(testRai), address(manager), 100000000000000 ether);
        u1.doDepositWithSlippage{value: 10 ether}(1000, uint(0 -1),  uint(0 -1));
    }

    function testFail_low_liquidity() public {
        u1.doApprove(address(testRai), address(manager), 100000000000000 ether);
        u1.doDeposit{value: 10 ether}(1);
    }



    function test_liquidty_proportional_to_balanceB() public {
        testRai.approve(address(manager), 10);
        testWeth.approve(address(manager), 10);
        helper_addLiquidity(1);

        // Make RAI twice more expensive
        helper_changeRedemptionPrice(2000000000 ether);

        // Add some liquidity
        helper_addLiquidity(1);

        // Return to the original price
        helper_changeRedemptionPrice(1200000000 ether);
        hevm.warp(2 days);


    
        (uint256 bal00) = token0.balanceOf(address(manager));
        (uint256 bal01) = token1.balanceOf(address(manager));
        manager.rebalance();
        (uint256 bal10) = token0.balanceOf(address(manager));
        (uint256 bal11) = token1.balanceOf(address(manager));

        emit log_named_uint("bal00", bal00); // 99999586913702
        emit log_named_uint("bal10", bal10); // 99998743003300
        emit log_named_uint("bal01", bal01); // 99199754914029
        emit log_named_uint("bal11", bal11); // 097604052593458

        // user should be able to withdraw it's whole balance. Balance != Liquidity
        u1.doWithdraw(uint128(manager.balanceOf(address(u1))));

        assertTrue(manager.totalSupply() == 0);

        (bytes32 id0, , , uint128 uniLiquidity0,,,) = manager.positions(0);
        (bytes32 id1, , , uint128 uniLiquidity1,,,) = manager.positions(1);

        assert(uniLiquidity0 == 0);
        assert(uniLiquidity1 == 0);

        (uint128 _liquidity0, , , , ) = pool.positions(id0);
        (uint128 _liquidity1, , , , ) = pool.positions(id1);

        assertTrue(_liquidity0 == 0);
        assertTrue(_liquidity1 == 0);

        // assertTrue(false);
    }

    function test_getter_return_correct_amount() public {
        helper_addLiquidity(1); //Starting with a bit of liquidity

        uint256 balance_u1 = manager.balanceOf(address(u1));

        (uint256 amount0, uint256 amount1) = manager.getTokenAmountsFromLiquidity(uint128(balance_u1));

        (uint256 ac_amount0, uint256 ac_amount1) = u1.doWithdraw(uint128(balance_u1));

        assertTrue(amount0 == ac_amount0);
        assertTrue(amount1 == ac_amount1);
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