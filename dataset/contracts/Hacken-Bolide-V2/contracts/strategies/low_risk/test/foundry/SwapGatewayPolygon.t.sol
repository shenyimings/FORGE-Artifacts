// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/SwapGateway.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract SwapGatewayPolygonTest is Test {
    uint256 private mainnetFork;

    address ownerInternal;
    address owner = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    SwapGateway public swapGateway;

    uint256 private constant BLOCK_NUMBER = 40_937_018;
    address sushiswapRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address uniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address quickswapV3Router = 0xf5b509bB0909a69B1c207E495f687a596C168E12;

    address USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address MATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    address private constant ZERO_ADDRESS = address(0);
    uint256 SWAP_MATIC = 10**17;

    address[] USDT_USDC;
    address[] USDC_USDT;
    address[] MATIC_USDT;
    address[] USDT_MATIC;
    address[] USDT_USDC_WETH_DAI;
    address[] DAI_WETH_USDC_USDT;
    address[] MATIC_USDT_USDC_WETH_DAI;
    address[] DAI_WETH_USDC_USDT_MATIC;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("polygon"), BLOCK_NUMBER);

        // SwapGateway Initialization
        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.setWETH(MATIC);
        swapGateway.addSwapRouter(sushiswapRouter, 2);
        swapGateway.addSwapRouter(uniswapV3Router, 3);
        swapGateway.addSwapRouter(quickswapV3Router, 5);

        // Define Path
        USDT_USDC = new address[](2);
        USDT_USDC[0] = USDT;
        USDT_USDC[1] = USDC;

        USDC_USDT = new address[](2);
        USDC_USDT[0] = USDC;
        USDC_USDT[1] = USDT;

        USDT_USDC_WETH_DAI = new address[](4);
        USDT_USDC_WETH_DAI[0] = USDT;
        USDT_USDC_WETH_DAI[1] = USDC;
        USDT_USDC_WETH_DAI[2] = WETH;
        USDT_USDC_WETH_DAI[3] = DAI;

        DAI_WETH_USDC_USDT = new address[](4);
        DAI_WETH_USDC_USDT[0] = DAI;
        DAI_WETH_USDC_USDT[1] = WETH;
        DAI_WETH_USDC_USDT[2] = USDC;
        DAI_WETH_USDC_USDT[3] = USDT;

        MATIC_USDT = new address[](2);
        MATIC_USDT[0] = ZERO_ADDRESS;
        MATIC_USDT[1] = USDT;

        USDT_MATIC = new address[](2);
        USDT_MATIC[0] = USDT;
        USDT_MATIC[1] = ZERO_ADDRESS;

        MATIC_USDT_USDC_WETH_DAI = new address[](5);
        MATIC_USDT_USDC_WETH_DAI[0] = ZERO_ADDRESS;
        MATIC_USDT_USDC_WETH_DAI[1] = USDT;
        MATIC_USDT_USDC_WETH_DAI[2] = USDC;
        MATIC_USDT_USDC_WETH_DAI[3] = ZERO_ADDRESS;
        MATIC_USDT_USDC_WETH_DAI[4] = DAI;

        DAI_WETH_USDC_USDT_MATIC = new address[](5);
        DAI_WETH_USDC_USDT_MATIC[0] = DAI;
        DAI_WETH_USDC_USDT_MATIC[1] = WETH;
        DAI_WETH_USDC_USDT_MATIC[2] = USDC;
        DAI_WETH_USDC_USDT_MATIC[3] = USDT;
        DAI_WETH_USDC_USDT_MATIC[4] = ZERO_ADDRESS;

        // Seed balance
        vm.deal(owner, 10**18);
    }

    function test_swapV2() public {
        _test_swap(sushiswapRouter);
    }

    function test_UniswapV3() public {
        _test_swap(uniswapV3Router);
    }

    function test_QuickswapV3() public {
        _test_swap(quickswapV3Router);
    }

    function test_UniswapV3quote() public {
        _test_quote(uniswapV3Router);
    }

    function test_QuickswapV3quote() public {
        _test_quote(quickswapV3Router);
    }

    function test_quoteV2() public {
        _test_quote(sushiswapRouter);
    }

    function _test_swap(address swapRouter) private {
        vm.startPrank(owner);

        uint256 MATIC_B;
        uint256 MATIC_A;
        uint256 USDT_B;
        uint256 USDT_A;
        uint256 USDC_B;
        uint256 USDC_A;
        uint256 DAI_B;
        uint256 DAI_A;
        uint256 USDT_O;

        IERC20MetadataUpgradeable(USDT).approve(
            address(swapGateway),
            type(uint256).max
        );
        IERC20MetadataUpgradeable(USDC).approve(
            address(swapGateway),
            type(uint256).max
        );
        IERC20MetadataUpgradeable(DAI).approve(
            address(swapGateway),
            type(uint256).max
        );

        // ********** Native Token Test ********** //

        // MATIC(Exact) -> USDT
        MATIC_B = address(owner).balance;
        USDT_B = IERC20MetadataUpgradeable(USDT).balanceOf(owner);
        ISwapGateway(swapGateway).swap{value: SWAP_MATIC}(
            swapRouter,
            SWAP_MATIC,
            0,
            MATIC_USDT,
            true,
            block.timestamp + 300
        );
        MATIC_A = address(owner).balance;
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);

        assertEq(MATIC_B, MATIC_A + SWAP_MATIC);
        assertEq(USDT_B < USDT_A, true);

        // MATIC -> USDT(Exact)
        MATIC_B = MATIC_A;
        USDT_B = USDT_A;
        ISwapGateway(swapGateway).swap{value: SWAP_MATIC}(
            swapRouter,
            SWAP_MATIC,
            10000,
            MATIC_USDT,
            false,
            block.timestamp + 300
        );
        MATIC_A = address(owner).balance;
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);

        console.log(swapGateway.quoteExactInput(swapRouter, 10000, USDT_MATIC));
        console.log(MATIC_B - MATIC_A);

        assertEq(MATIC_B > MATIC_A, true);
        assertEq(USDT_B + 10000, USDT_A);

        // USDT -> MATIC(Exact)
        MATIC_B = MATIC_A;
        USDT_B = USDT_A;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            USDT_B,
            SWAP_MATIC,
            USDT_MATIC,
            false,
            block.timestamp + 300
        );
        MATIC_A = address(owner).balance;
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);

        assertEq(MATIC_B + SWAP_MATIC, MATIC_A);
        assertEq(USDT_B > USDT_A, true);

        // USDT(Exact) -> MATIC
        MATIC_B = MATIC_A;
        USDT_B = USDT_A;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            USDT_B,
            0,
            USDT_MATIC,
            true,
            block.timestamp + 300
        );
        MATIC_A = address(owner).balance;
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);

        assertEq(MATIC_B < MATIC_A, true);
        assertEq(USDT_A, 0);

        // MATIC(Exact) -> USDT -> USDC -> WETH -> DAI
        MATIC_B = address(owner).balance;
        DAI_B = IERC20MetadataUpgradeable(DAI).balanceOf(owner);
        ISwapGateway(swapGateway).swap{value: SWAP_MATIC}(
            swapRouter,
            SWAP_MATIC,
            0,
            MATIC_USDT_USDC_WETH_DAI,
            true,
            block.timestamp + 300
        );
        MATIC_A = address(owner).balance;
        DAI_A = IERC20MetadataUpgradeable(DAI).balanceOf(owner);

        assertEq(MATIC_B, MATIC_A + SWAP_MATIC);
        assertEq(DAI_B < DAI_A, true);

        // MATIC -> USDT -> USDC -> WETH -> DAI(Exact)
        MATIC_B = MATIC_A;
        DAI_B = DAI_A;
        ISwapGateway(swapGateway).swap{value: SWAP_MATIC}(
            swapRouter,
            SWAP_MATIC,
            10000,
            MATIC_USDT_USDC_WETH_DAI,
            false,
            block.timestamp + 300
        );
        MATIC_A = address(owner).balance;
        DAI_A = IERC20MetadataUpgradeable(DAI).balanceOf(owner);

        assertEq(MATIC_B > MATIC_A, true);
        assertEq(DAI_B + 10000, DAI_A);

        // DAI -> WETH -> USDC -> USDT -> MATIC(Exact)
        MATIC_B = MATIC_A;
        DAI_B = DAI_A;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            DAI_B,
            SWAP_MATIC / 2,
            DAI_WETH_USDC_USDT_MATIC,
            false,
            block.timestamp + 300
        );
        MATIC_A = address(owner).balance;
        DAI_A = IERC20MetadataUpgradeable(DAI).balanceOf(owner);

        assertEq(MATIC_B + SWAP_MATIC / 2, MATIC_A);
        assertEq(DAI_B > DAI_A, true);

        // DAI(Exact) -> WETH -> USDC -> USDT -> MATIC
        MATIC_B = MATIC_A;
        DAI_B = DAI_A;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            DAI_B,
            0,
            DAI_WETH_USDC_USDT_MATIC,
            true,
            block.timestamp + 300
        );
        MATIC_A = address(owner).balance;
        DAI_A = IERC20MetadataUpgradeable(DAI).balanceOf(owner);

        assertEq(MATIC_B < MATIC_A, true);
        assertEq(DAI_A, 0);

        // ********** Token - Token Test ********** //
        ISwapGateway(swapGateway).swap{value: SWAP_MATIC * 5}(
            swapRouter,
            SWAP_MATIC * 5,
            0,
            MATIC_USDT,
            true,
            block.timestamp + 300
        );
        USDT_O = IERC20MetadataUpgradeable(USDT).balanceOf(owner);

        // USDT(Exact) -> USDC
        USDT_B = USDT_O;
        USDC_B = IERC20MetadataUpgradeable(USDC).balanceOf(owner);
        ISwapGateway(swapGateway).swap(
            swapRouter,
            USDT_B,
            0,
            USDT_USDC,
            true,
            block.timestamp + 300
        );
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);
        USDC_A = IERC20MetadataUpgradeable(USDC).balanceOf(owner);

        assertEq(USDT_A, 0);
        assertEq(USDC_A > USDC_B, true);

        // USDC -> USDT(Exact)
        USDT_B = USDT_A;
        USDC_B = USDC_A;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            USDC_B,
            USDT_O / 2,
            USDC_USDT,
            false,
            block.timestamp + 300
        );
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);
        USDC_A = IERC20MetadataUpgradeable(USDC).balanceOf(owner);

        assertEq(USDT_A, USDT_B + USDT_O / 2);
        assertEq(USDC_A < USDC_B, true);

        // USDT(Exact) -> USDC -> WETH -> DAI
        USDT_B = USDT_A;
        DAI_B = IERC20MetadataUpgradeable(DAI).balanceOf(owner);
        ISwapGateway(swapGateway).swap(
            swapRouter,
            USDT_B,
            0,
            USDT_USDC_WETH_DAI,
            true,
            block.timestamp + 300
        );
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);
        DAI_A = IERC20MetadataUpgradeable(DAI).balanceOf(owner);

        assertEq(USDT_A, 0);
        assertEq(DAI_A > DAI_B, true);

        // DAI -> WETH -> USDC -> USDT(Exact)
        USDT_B = USDT_A;
        DAI_B = DAI_A;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            DAI_B,
            USDT_O / 4,
            DAI_WETH_USDC_USDT,
            false,
            block.timestamp + 300
        );
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);
        DAI_A = IERC20MetadataUpgradeable(DAI).balanceOf(owner);

        assertEq(USDT_A, USDT_B + USDT_O / 4);
        assertEq(DAI_A < DAI_B, true);

        // Return DAI, USDC to USDT
        ISwapGateway(swapGateway).swap(
            swapRouter,
            DAI_A,
            0,
            DAI_WETH_USDC_USDT,
            true,
            block.timestamp + 300
        );
        ISwapGateway(swapGateway).swap(
            swapRouter,
            USDC_A,
            0,
            USDC_USDT,
            true,
            block.timestamp + 300
        );
        assertEq(
            USDT_O > IERC20MetadataUpgradeable(USDT).balanceOf(owner),
            true
        );
        assertEq(IERC20MetadataUpgradeable(USDC).balanceOf(owner), 0);
        assertEq(IERC20MetadataUpgradeable(DAI).balanceOf(owner), 0);

        vm.stopPrank();
    }

    function _test_quote(address swapRouter) private {
        uint256 amountOut;
        uint256 amountOutReverse;

        amountOut = swapGateway.quoteExactInput(swapRouter, 1000000, USDC_USDT);
        console.log("USDC-USDT", amountOut);

        assertEq(amountOut > 990000, true);
        assertEq(amountOut < 1010000, true);

        amountOutReverse = swapGateway.quoteExactInput(
            swapRouter,
            1000000,
            USDT_USDC
        );
        console.log("USDT-USDC", amountOutReverse);

        assertEq(amountOutReverse > 990000, true);
        assertEq(amountOutReverse < 1010000, true);

        assertEq(amountOut * amountOutReverse > 990000000000, true);

        amountOut = swapGateway.quoteExactInput(
            swapRouter,
            1000000,
            USDT_USDC_WETH_DAI
        );
        console.log("USDT-DAI", amountOut);

        assertEq(amountOut > 990000000000000000, true);
        assertEq(amountOut < 1010000000000000000, true);

        amountOutReverse = swapGateway.quoteExactInput(
            swapRouter,
            10**18,
            DAI_WETH_USDC_USDT
        );
        console.log("DAI-USDT", amountOutReverse);

        assertEq(amountOutReverse > 980000, true);
        assertEq(amountOutReverse < 1020000, true);

        assertEq((amountOut * amountOutReverse) / 10**12 > 980000000000, true);

        amountOut = swapGateway.quoteExactInput(swapRouter, 10**18, MATIC_USDT);
        console.log("MATIC-USDT", amountOut);

        amountOutReverse = swapGateway.quoteExactInput(
            swapRouter,
            10**6,
            USDT_MATIC
        );
        console.log("USDT-MATIC", amountOutReverse);

        assertEq((amountOut * amountOutReverse) / 10**12 > 990000000000, true);

        amountOut = swapGateway.quoteExactInput(
            swapRouter,
            10**18,
            MATIC_USDT_USDC_WETH_DAI
        );
        console.log("MATIC-DAI", amountOut);

        amountOutReverse = swapGateway.quoteExactInput(
            swapRouter,
            10**18,
            DAI_WETH_USDC_USDT_MATIC
        );
        console.log("DAI-MATIC", amountOutReverse);

        assertEq(
            (amountOut * amountOutReverse) / 10**18 > 970000000000000000,
            true
        );
    }
}
