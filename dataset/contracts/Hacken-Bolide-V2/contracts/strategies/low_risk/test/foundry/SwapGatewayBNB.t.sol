// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/SwapGateway.sol";
import "../../contracts/interfaces/ISwap.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract SwapGatewayBNBTest is Test {
    uint256 private mainnetFork;

    address ownerInternal;
    address owner = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    SwapGateway public swapGateway;

    uint256 private constant BLOCK_NUMBER = 27_050_910;
    address private constant ZERO_ADDRESS = address(0);

    address dodoV2Proxy02 = 0x8F8Dd7DB1bDA5eD3da8C9daf3bfa471c12d58486;

    address USX = 0xB5102CeE1528Ce2C760893034A4603663495fD72;
    address DF = 0x4A9A2b2b04549C3927dd2c9668A5eF3fCA473623;
    address BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address USDT = 0x55d398326f99059fF775485246999027B3197955;
    address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address BNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address USX_DF = 0xB69fdC6531e08B366616aB30b8481bf4148786cB;
    address USX_BUSD = 0xb19265426ce5bC1E015C0c503dFe6EF7c407a406;
    address BUSD_BNB = 0x0F36544D0B1A107B98EdFabB1d95538C316C1DcD;

    address BNB_USDT = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;
    address USDC_BUSD = 0x70699941e5ADC6b932b2b78BA2f505311bBB3281;
    address USDC_BNB = 0x33AaA3220d8E4f600Ed1F21C24d7dBE3963265f6;

    uint256 SWAP_BNB = 10**17;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("bsc"), BLOCK_NUMBER);

        // SwapGateway Initialization
        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.setWETH(BNB);
        swapGateway.addSwapRouter(dodoV2Proxy02, 4);

        // Seed balance
        vm.deal(owner, 10**18);
    }

    function test_swapDODO() public {
        _test_swap(dodoV2Proxy02);
    }

    function test_quoteDODO() public {
        uint256 amountOut;
        address[] memory path;
        int256 diff;

        path = new address[](2);
        path[0] = BNB;
        path[1] = BUSD_BNB;
        amountOut = swapGateway.quoteExactInput(dodoV2Proxy02, 10**18, path);
        console.log(amountOut);

        path = new address[](2);
        path[0] = BUSD;
        path[1] = BUSD_BNB;
        amountOut = swapGateway.quoteExactInput(dodoV2Proxy02, amountOut, path);
        console.log(amountOut);

        path = new address[](2);
        path[0] = DF;
        path[1] = USX_DF;
        amountOut = swapGateway.quoteExactInput(dodoV2Proxy02, 10**18, path);

        path = new address[](2);
        path[0] = USX;
        path[1] = USX_DF;
        amountOut = swapGateway.quoteExactInput(dodoV2Proxy02, amountOut, path);
        console.log(amountOut);
        diff = 10**18 - int256(amountOut);
        if (diff < 0) diff = 0 - diff;
        assertEq(diff < 10**16, true);

        path = new address[](2);
        path[0] = BUSD;
        path[1] = USX_BUSD;
        amountOut = swapGateway.quoteExactInput(dodoV2Proxy02, 10**18, path);
        console.log(amountOut);

        path = new address[](2);
        path[0] = USX;
        path[1] = USX_BUSD;
        amountOut = swapGateway.quoteExactInput(dodoV2Proxy02, amountOut, path);
        console.log(amountOut);
        diff = 10**18 - int256(amountOut);
        if (diff < 0) diff = 0 - diff;
        assertEq(diff < 10**16, true);

        path = new address[](3);
        path[0] = DF;
        path[1] = USX_DF;
        path[2] = USX_BUSD;
        amountOut = swapGateway.quoteExactInput(dodoV2Proxy02, 10**18, path);
        console.log(amountOut);

        path = new address[](3);
        path[0] = BUSD;
        path[1] = USX_BUSD;
        path[2] = USX_DF;
        amountOut = swapGateway.quoteExactInput(dodoV2Proxy02, amountOut, path);
        console.log(amountOut);
        diff = 10**18 - int256(amountOut);
        if (diff < 0) diff = 0 - diff;
        assertEq(diff < 10**16, true);
    }

    function _test_swap(address swapRouter) private {
        vm.startPrank(owner);

        address[] memory path;

        uint256 BNB_B;
        uint256 BNB_A;
        uint256 USDT_B;
        uint256 USDT_A;
        uint256 BUSD_B;
        uint256 BUSD_A;
        uint256 DF_B;
        uint256 DF_A;

        IERC20MetadataUpgradeable(USDT).approve(
            address(swapGateway),
            type(uint256).max
        );
        IERC20MetadataUpgradeable(BUSD).approve(
            address(swapGateway),
            type(uint256).max
        );
        IERC20MetadataUpgradeable(BNB).approve(
            address(swapGateway),
            type(uint256).max
        );

        IERC20MetadataUpgradeable(DF).approve(
            address(swapGateway),
            type(uint256).max
        );

        // ********** Native Token Test ********** //

        // BNB(Exact) -> USDT using BNB_USDT
        BNB_B = address(owner).balance;
        USDT_B = IERC20MetadataUpgradeable(USDT).balanceOf(owner);
        path = new address[](3);
        path[0] = ZERO_ADDRESS;
        path[1] = BNB_USDT;
        path[2] = USDT;
        ISwapGateway(swapGateway).swap{value: SWAP_BNB}(
            swapRouter,
            SWAP_BNB,
            1,
            path,
            false,
            block.timestamp + 300 + (10**18 * 0)
        );

        BNB_A = address(owner).balance;
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);

        assertEq(BNB_B, BNB_A + SWAP_BNB);
        assertEq(USDT_B < USDT_A, true);

        // USDT(Exact) -> BNB using BNB_USDT
        BNB_B = BNB_A;
        USDT_B = USDT_A;
        path = new address[](3);
        path[0] = USDT;
        path[1] = BNB_USDT;
        path[2] = ZERO_ADDRESS;
        uint256[] memory amounts;
        amounts = ISwapGateway(swapGateway).swap(
            swapRouter,
            USDT_B,
            1,
            path,
            false,
            block.timestamp + 300 + (10**18 * 1)
        );

        BNB_A = address(owner).balance;
        USDT_A = IERC20MetadataUpgradeable(USDT).balanceOf(owner);

        assertEq(BNB_B < BNB_A, true);
        assertEq(USDT_B > USDT_A, true);
        assertEq(USDT_A, 0);

        // BNB(Exact) -> BUSD using BUSD_BNB
        BNB_B = address(owner).balance;
        BUSD_B = IERC20MetadataUpgradeable(BUSD).balanceOf(owner);
        path = new address[](3);
        path[0] = ZERO_ADDRESS;
        path[1] = BUSD_BNB;
        path[2] = BUSD;
        ISwapGateway(swapGateway).swap{value: SWAP_BNB}(
            swapRouter,
            SWAP_BNB,
            1,
            path,
            false,
            block.timestamp + 300 + (10**18 * 1)
        );

        BNB_A = address(owner).balance;
        BUSD_A = IERC20MetadataUpgradeable(BUSD).balanceOf(owner);

        assertEq(BNB_B, BNB_A + SWAP_BNB);
        assertEq(BUSD_B < BUSD_A, true);

        // BUSD(Exact) -> DF using USX_BUSD, USX_DF
        BUSD_B = BUSD_A;
        DF_B = IERC20MetadataUpgradeable(DF).balanceOf(owner);
        path = new address[](4);
        path[0] = BUSD;
        path[1] = USX_BUSD;
        path[2] = USX_DF;
        path[3] = DF;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            BUSD_B,
            1,
            path,
            false,
            block.timestamp + 300 + (10**18 * 1)
        );

        BUSD_A = IERC20MetadataUpgradeable(BUSD).balanceOf(owner);
        DF_A = IERC20MetadataUpgradeable(DF).balanceOf(owner);

        assertEq(BUSD_B > BUSD_A, true);
        assertEq(BUSD_A, 0);
        assertEq(DF_B < DF_A, true);

        // DF(Exact) -> BUSD using USX_BUSD, USX_DF
        BUSD_B = BUSD_A;
        DF_B = DF_A;
        path = new address[](4);
        path[0] = DF;
        path[1] = USX_DF;
        path[2] = USX_BUSD;
        path[3] = BUSD;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            DF_B,
            1,
            path,
            false,
            block.timestamp + 300 + (10**18 * 1)
        );

        BUSD_A = IERC20MetadataUpgradeable(BUSD).balanceOf(owner);
        DF_A = IERC20MetadataUpgradeable(DF).balanceOf(owner);

        assertEq(BUSD_B < BUSD_A, true);
        assertEq(DF_B > DF_A, true);
        assertEq(DF_A, 0);

        // BUSD(Exact) -> BNB using BUSD_BNB
        BNB_B = address(owner).balance;
        BUSD_B = BUSD_A;
        path = new address[](3);
        path[0] = BUSD;
        path[1] = BUSD_BNB;
        path[2] = ZERO_ADDRESS;
        ISwapGateway(swapGateway).swap(
            swapRouter,
            BUSD_B,
            1,
            path,
            false,
            block.timestamp + 300 + (10**18 * 0)
        );

        BNB_A = address(owner).balance;
        BUSD_A = IERC20MetadataUpgradeable(BUSD).balanceOf(owner);

        assertEq(BNB_B < BNB_A, true);
        assertEq(BUSD_B > BUSD_A, true);
        assertEq(BUSD_A, 0);

        vm.stopPrank();
    }
}
