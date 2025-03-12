pragma solidity 0.6.7;

import "../../lib/ds-test/src/test.sol";
import "../GebUniswapV3ManagerBase.sol";
import "../uni/UniswapV3Factory.sol";
import "../uni/UniswapV3Pool.sol";
import "./TestHelpers.sol";
import "./OracleLikeMock.sol";

contract GebUniswapV3ManagerBaseTest is DSTest {
    using SafeMath for uint256;

    Hevm hevm;

    GebUniswapV3ManagerBase manager_base;
    UniswapV3Pool pool;

    TestRAI testRai;
    TestWETH testWeth;

    OracleLikeMock oracle;
    PoolViewer pv;

    TestToken token0;
    TestToken token1;

    uint160 initialPoolPrice;

    PoolUser u1;
    PoolUser u2;
    PoolUser u3;
    PoolUser u4;

    PoolUser[4] public users;

    function setUp() virtual public {
        // Deploy GEB
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        oracle = new OracleLikeMock();

        // Deploy each token
        testRai = new TestRAI("RAI");
        
        testWeth = new TestWETH("WETH");
        (token0, token1) = address(testRai) < address(testWeth) ? (TestToken(testRai), TestToken(testWeth)) : (TestToken(testWeth), TestToken(testRai));

        pv = new PoolViewer();

        // Deploy Pool
        pool = UniswapV3Pool(helper_deployV3Pool(address(token0), address(token1), 3000));
    }

    // --- Math ---
    function sqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // --- Helpers ---
    function helper_deployV3Pool(
        address _token0,
        address _token1,
        uint256 _fee
    ) internal returns (address _pool) {
        UniswapV3Factory fac = new UniswapV3Factory();
        _pool = fac.createPool(_token0, _token1, uint24(_fee));
    }

    function helper_changeRedemptionPrice(uint256 newPrice) public {
        oracle.setSystemCoinPrice(newPrice);
    }

    function helper_transferToAdds(PoolUser[4] memory adds) public {
        for (uint256 i = 0; i < adds.length; i++) {
            testWeth.transfer(address(adds[i]), 30000 ether);
            testRai.transfer(address(adds[i]), 120000000000 ether);
        }
    }

    function helper_getRebalancePrice() public returns (uint160) {
        // 1. Get prices from the oracle
        (uint256 redemptionPrice, uint256 ethUsdPrice) = manager_base.getPrices();

        // 2. Calculate the price ratio
         uint160 sqrtPriceX96;
        uint256 scale = 1000000000;
        if (address(token0) == address(testRai)) {
          sqrtPriceX96 = uint160(sqrt((redemptionPrice.mul(scale).div(ethUsdPrice) << 192) / scale));
        } else {
          sqrtPriceX96 = uint160(sqrt((ethUsdPrice.mul(scale).div(redemptionPrice) << 192) / scale));
        }
        return sqrtPriceX96;
    }

    function helper_getLiquidityAmountsForTicks(
        uint160 sqrtRatioX96,
        int24 _lowerTick,
        int24 upperTick,
        uint256 t0am,
        uint256 t1am
    ) public returns (uint128 liquidity) {
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(_lowerTick),
            TickMath.getSqrtRatioAtTick(upperTick),
            t0am,
            t1am
        );
    }

    function helper_getAbsInt24(int24 val) public returns (uint256 abs) {
        if (val > 0) {
            abs = uint256(val);
        } else {
            abs = uint256(val * int24(-1));
        }
    }

    function helper_logTick(int24 val) public {
        if(val > 0){
            emit log_named_uint("pos",uint256(val) );
        } else {
            emit log_named_uint("neg",uint256(val * int24(-1)));
        }
    }

    function helper_do_swap() public {
        (uint160 currentPrice, , , , , , ) = pool.slot0();

        uint160 sqrtLimitPrice = currentPrice + 1 ether ;
        pool.swap(address(this), false, 1 ether, sqrtLimitPrice, bytes(""));
    }

    function helper_assert_is_close(uint256 val1, uint256 val2) public {
        bool eq = val1 == val2;
        bool bg = val1 + 1 == val2;
        bool sm = val1 - 1 == val2;
        emit log_named_uint("eq", eq ? 1 :0);
        emit log_named_uint("bg", bg ? 1 :0);
        emit log_named_uint("sm", sm ? 1 :0);
        assertTrue(eq || bg || sm);
    }

    function helper_addWhaleLiquidity() public {
        uint256 token0Am = 1000 ether;
        uint256 token1Am = 1000 ether;
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        int24 low = -600000;
        int24 upp = 600000;
        uint128 liq = helper_getLiquidityAmountsForTicks(sqrtRatioX96, low, upp, token0Am, token1Am);
        pool.mint(address(this), low, upp, liq, bytes(""));

        low = -120000;
        upp = 120000;
        liq = helper_getLiquidityAmountsForTicks(sqrtRatioX96, low, upp, token0Am, token1Am);
        pool.mint(address(this), low, upp, liq, bytes(""));

    }

        

     // --- Uniswap Callbacks ---
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        testRai.transfer(msg.sender, amount0Owed);
        testWeth.transfer(msg.sender, amount0Owed);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta > 0) token0.transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) token1.transfer(msg.sender, uint256(amount1Delta));

    }

}
