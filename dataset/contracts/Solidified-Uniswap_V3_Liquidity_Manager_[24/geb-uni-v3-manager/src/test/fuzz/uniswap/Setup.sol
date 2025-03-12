pragma solidity 0.6.7;
pragma experimental ABIEncoderV2;

import "../../TestHelpers.sol";
import "../../../uni/UniswapV3Pool.sol";
import "../../../GebUniswapV3LiquidityManager.sol";
import "../../../uni/UniswapV3Factory.sol";

contract SetupTokens {
    TestToken public token0;
    TestToken public token1;

    constructor() public {
        // create the token wrappers
        TestToken t0 = new TestToken("tkn", 1000000 ether);
        TestToken t1 = new TestToken("tkn", 1000000 ether);

        // switch them around so that token0's address is lower than token1's
        // since this is what the uniswap factory will do when you create the pool
        if (address(t0) > address(t1)) {
            (token1, token0) = (t0, t1);
        } else {
            (token0, token1) = (t0, t1);
        }
    }

    // mint either token0 or token1 to a chosen account
    function mintTo(
        uint256 _tokenIdx,
        address _recipient,
        uint256 _amount
    ) public {
        require(_tokenIdx == 0 || _tokenIdx == 1, "invalid token idx");
        if (_tokenIdx == 0) token0.mintTo(_recipient, _amount);
        if (_tokenIdx == 1) token1.mintTo(_recipient, _amount);
    }
}

contract SetupUniswap {
    UniswapV3Pool public pool;
    TestToken token0;
    TestToken token1;

    // will create the following enabled fees and corresponding tickSpacing
    // fee 500   + tickSpacing 10
    // fee 3000  + tickSpacing 60
    // fee 10000 + tickSpacing 200
    UniswapV3Factory factory;

    constructor(TestToken _token0, TestToken _token1) public {
        factory = new UniswapV3Factory();
        token0 = _token0;
        token1 = _token1;
    }

    function createPool(uint24 _fee, uint160 _startPrice) public {
        pool = UniswapV3Pool(factory.createPool(address(token0), address(token1), _fee));
        pool.initialize(_startPrice);
    }
}

contract UniswapMinter {
    UniswapV3Pool pool;
    TestToken token0;
    TestToken token1;

    struct MinterStats {
        uint128 liq;
        uint128 tL_liqGross;
        int128 tL_liqNet;
        uint128 tU_liqGross;
        int128 tU_liqNet;
    }

    constructor(TestToken _token0, TestToken _token1) public {
        token0 = _token0;
        token1 = _token1;
    }

    function setPool(UniswapV3Pool _pool) public {
        pool = _pool;
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        if (amount0Owed > 0) token0.transfer(address(pool), amount0Owed);
        if (amount1Owed > 0) token1.transfer(address(pool), amount1Owed);
    }

    function getTickLiquidityVars(int24 _tickLower, int24 _tickUpper)
        internal
        view
        returns (
            uint128,
            int128,
            uint128,
            int128
        )
    {
        (uint128 tL_liqGross, int128 tL_liqNet, , ) = pool.ticks(_tickLower);
        (uint128 tU_liqGross, int128 tU_liqNet, , ) = pool.ticks(_tickUpper);
        return (tL_liqGross, tL_liqNet, tU_liqGross, tU_liqNet);
    }

    function getStats(int24 _tickLower, int24 _tickUpper) internal view returns (MinterStats memory stats) {
        (uint128 tL_lg, int128 tL_ln, uint128 tU_lg, int128 tU_ln) = getTickLiquidityVars(_tickLower, _tickUpper);
        return MinterStats(pool.liquidity(), tL_lg, tL_ln, tU_lg, tU_ln);
    }

    function doMint(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _amount
    ) public returns (MinterStats memory bfre, MinterStats memory aftr) {
        bfre = getStats(_tickLower, _tickUpper);
        pool.mint(address(this), _tickLower, _tickUpper, _amount, new bytes(0));
        aftr = getStats(_tickLower, _tickUpper);
    }

    function doBurn(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _amount
    ) public returns (MinterStats memory bfre, MinterStats memory aftr) {
        bfre = getStats(_tickLower, _tickUpper);
        pool.burn(_tickLower, _tickUpper, _amount);
        aftr = getStats(_tickLower, _tickUpper);
    }
}

contract UniswapSwapper {
    UniswapV3Pool pool;
    TestToken token0;
    TestToken token1;

    struct SwapperStats {
        uint128 liq;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint256 bal0;
        uint256 bal1;
        int24 tick;
    }

    constructor(TestToken _token0, TestToken _token1) public {
        token0 = _token0;
        token1 = _token1;
    }

    function setPool(UniswapV3Pool _pool) public virtual {
        pool = _pool;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta > 0) token0.transfer(address(pool), uint256(amount0Delta));
        if (amount1Delta > 0) token1.transfer(address(pool), uint256(amount1Delta));
    }

    function doSwap(
        bool _zeroForOne,
        int256 _amountSpecified,
        uint160 _sqrtPriceLimitX96
    ) public {
        pool.swap(address(this), _zeroForOne, _amountSpecified, _sqrtPriceLimitX96, new bytes(0));
    }
}

contract FuzzUser {
    GebUniswapV3LiquidityManager manager;
    UniswapV3Pool pool;
    TestToken token0;
    TestToken token1;

    struct MinterStats {
        uint128 liq;
        uint128 tL_liqGross;
        int128 tL_liqNet;
        uint128 tU_liqGross;
        int128 tU_liqNet;
    }

    constructor(
        GebUniswapV3LiquidityManager man,
        TestToken _token0,
        TestToken _token1
    ) public {
        token0 = _token0;
        token1 = _token1;
        manager = man;
    }

    struct SwapperStats {
        uint128 liq;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint256 bal0;
        uint256 bal1;
        int24 tick;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta > 0) token0.transfer(address(pool), uint256(amount0Delta));
        if (amount1Delta > 0) token1.transfer(address(pool), uint256(amount1Delta));
    }

    function doSwap(
        bool _zeroForOne,
        int256 _amountSpecified,
        uint160 _sqrtPriceLimitX96
    ) public {
        pool.swap(address(this), _zeroForOne, _amountSpecified, _sqrtPriceLimitX96, new bytes(0));
    }

    function setPool(UniswapV3Pool _pool) public {
        pool = _pool;
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        if (amount0Owed > 0) token0.transfer(address(pool), amount0Owed);
        if (amount1Owed > 0) token1.transfer(address(pool), amount1Owed);
    }

    function getTickLiquidityVars(int24 _tickLower, int24 _tickUpper)
        internal
        view
        returns (
            uint128,
            int128,
            uint128,
            int128
        )
    {
        (uint128 tL_liqGross, int128 tL_liqNet, , ) = pool.ticks(_tickLower);
        (uint128 tU_liqGross, int128 tU_liqNet, , ) = pool.ticks(_tickUpper);
        return (tL_liqGross, tL_liqNet, tU_liqGross, tU_liqNet);
    }

    function getStats(int24 _tickLower, int24 _tickUpper) internal view returns (MinterStats memory stats) {
        (uint128 tL_lg, int128 tL_ln, uint128 tU_lg, int128 tU_ln) = getTickLiquidityVars(_tickLower, _tickUpper);
        return MinterStats(pool.liquidity(), tL_lg, tL_ln, tU_lg, tU_ln);
    }

    function doMint(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _amount
    ) public {
        pool.mint(address(this), _tickLower, _tickUpper, _amount, new bytes(0));
    }

    function doBurn(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _amount
    ) public {
        pool.burn(_tickLower, _tickUpper, _amount);
    }

    function doCollectFromPool(
        int24 lowerTick,
        int24 upperTick,
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) public {
        pool.collect(recipient, lowerTick, upperTick, amount0Requested, amount1Requested);
    }

    function doTransfer(
        address token,
        address to,
        uint256 amount
    ) public {
        ERC20(token).transfer(to, amount);
    }

    function doDeposit(uint128 liquidityAmount) public {
        manager.deposit(liquidityAmount, address(this),0,0);
    }

    function doWithdraw(uint128 liquidityAmount) public returns (uint256 amount0, uint256 amount1) {
        uint128 max_uint128 = uint128(0 - 1);
        (amount0, amount1) = manager.withdraw(liquidityAmount, address(this));
    }

    function doApprove(
        address token,
        address who,
        uint256 amount
    ) public {
        IERC20(token).approve(who, amount);
    }
}
