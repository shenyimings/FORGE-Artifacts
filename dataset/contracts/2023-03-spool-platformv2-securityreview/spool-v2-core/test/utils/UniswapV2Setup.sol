// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../external/uniswap/UniswapV2Factory.sol";
import "../external/uniswap/UniswapV2Router02.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";

import "../mocks/MockWeth.sol";
import "../mocks/MockToken.sol";

contract UniswapV2Setup is Test {
    address private constant LIQUIDITY_PROVIDER = address(0x99);
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETH9 public weth;

    function test_lib() external pure {}

    constructor() {
        factory = new UniswapV2Factory(address(0));

        weth = new WETH9();
        router = new UniswapV2Router02(address(factory), address(weth));
    }

    function addLiquidity(address tokenA, uint256 amountA, address tokenB, uint256 amountB, address to) external {
        // mint tokens
        deal(tokenA, LIQUIDITY_PROVIDER, amountA, true);
        deal(tokenB, LIQUIDITY_PROVIDER, amountB, true);

        if (to == address(0)) {
            to = LIQUIDITY_PROVIDER;
        }

        // add liquidity
        startHoax(LIQUIDITY_PROVIDER);
        IERC20(tokenA).approve(address(router), type(uint256).max);
        IERC20(tokenB).approve(address(router), type(uint256).max);
        router.addLiquidity(tokenA, tokenB, amountA, amountB, 0, 0, to, type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Mints assets in correct ratio directly to a tradepair, imitating profit made from swapping.
    function addProfitToPair(address tokenA, address tokenB, uint256 relativeProfit) external {
        // skip(1);
        address pair = factory.getPair(tokenA, tokenB);

        (uint256 reserveA, uint256 reserveB,) = IUniswapV2Pair(pair).getReserves();

        uint256 tokenAProfit = reserveA * relativeProfit / 100_00;
        uint256 tokenBProfit = reserveB * relativeProfit / 100_00;

        console.log("addProfitToPair");
        console.log("   reserveA:", reserveA);
        console.log("   reserveB:", reserveB);
        console.log("   tokenAProfit:", tokenAProfit);
        console.log("   tokenBProfit:", tokenBProfit);

        (tokenA, tokenB) = UniswapV2Library.sortTokens(tokenA, tokenB);

        deal(tokenA, pair, reserveA + tokenAProfit, true);
        deal(tokenB, pair, reserveB + tokenBProfit, true);

        IUniswapV2Pair(pair).sync();
    }
}
