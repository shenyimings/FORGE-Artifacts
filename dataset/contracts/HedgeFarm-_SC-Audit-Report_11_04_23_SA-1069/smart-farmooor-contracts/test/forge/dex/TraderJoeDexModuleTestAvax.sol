// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../script/Deployer.s.sol";
import "../helper/TestHelper.sol";

contract TraderJoeDexModuleTest is Deployer, TestHelper {

    uint256 public WAVAX_AMOUNT;

    address[] public newRoute;
    address[][] public newRoutes;

    function setUp() public {
        loadTestData();

        deployDex();
        transferOwnershipDex(OWNER);

        WAVAX_AMOUNT = 100 * 10 ** IERC20Metadata(WAVAX).decimals();

        newRoute = [DEX_WAVAX_USDC_ROUTE[0], DEX_STG_USDC_ROUTE[0]];
        newRoutes = [newRoute];
    }

    function testInitIsCorrect() public {
        verifyDex(OWNER);
    }

    function testAddRoute() public {
        setNewRoute();
        assertEq(dex.getRoute(newRoute[0], newRoute[1]), newRoute);
        IERC20(newRoute[0]).allowance(address(dex), TRADER_JOE_ROUTER);
    }

    function testUpdateRoute() public {
        setNewRoute();
        newRoute[1] = DEX_WAVAX_USDC_ROUTE[0];
        newRoutes = [newRoute];
        vm.prank(OWNER);
        dex.setRoutes(newRoutes);
        assertEq(dex.getRoute(newRoute[0], newRoute[1]), newRoute);
        IERC20(newRoute[0]).allowance(address(dex), TRADER_JOE_ROUTER);
    }

    function testRemoveRoute() public {
        setNewRoute();

        newRoute = DEX_WAVAX_USDC_ROUTE;
        newRoutes = [newRoute];
        vm.prank(OWNER);
        dex.deleteRoutes(routes);
        assertEq(dex.getRoute(DEX_WAVAX_USDC_ROUTE[0], DEX_WAVAX_USDC_ROUTE[1]).length, 0);
    }

    function testSwapPreview() public {
        uint256 amountMinOut = WAVAX_AMOUNT * 98 / 100 * chainlinkPrice(CHAINLINK_AVAX) / chainlinkPrice(CHAINLINK_USDC) * 10 ** IERC20Metadata(USDC).decimals() / 10 ** IERC20Metadata(WAVAX).decimals();
        uint256 previewAmount = dex.swapPreview(WAVAX_AMOUNT, WAVAX, USDC);
        assertGe(previewAmount, amountMinOut);
    }

    function testSwapPreviewReturnZeroIfAmountInIsZero() public {
        uint256 previewAmount = dex.swapPreview(0, WAVAX, USDC);
        assertGe(previewAmount, 0);
    }

    // NOTE: this test ensures that all routes are correct
    function testSwap() public {
        for (uint256 i = 0; i < routes.length; i++) {
            deal(routes[i][0], ALICE, 100 * 10 ** IERC20Metadata(routes[i][0]).decimals());
            deal(routes[i][routes[i].length - 1], ALICE, 0);
            assertEq(IERC20(routes[i][routes[i].length - 1]).balanceOf(ALICE), 0);
            vm.startPrank(ALICE);
            IERC20(routes[i][0]).approve(address(dex), type(uint256).max);
            dex.swap(100 * 10 ** IERC20Metadata(routes[i][0]).decimals(), routes[i][0], routes[i][routes[i].length - 1], ALICE);
            vm.stopPrank();
            assertGt(IERC20(routes[i][routes[i].length - 1]).balanceOf(ALICE), 0);
            assertEq(IERC20(routes[i][0]).balanceOf(ALICE), 0);
        }
    }

    function testSwapDoNotSwapIfAmountOutIsZero() public {
        deal(WAVAX, ALICE, WAVAX_AMOUNT);
        assertEq(IERC20(USDC).balanceOf(ALICE), 0);
        vm.startPrank(ALICE);
        IERC20(WAVAX).approve(address(dex), type(uint256).max);
        dex.swap(0, WAVAX, USDC, ALICE);
        vm.stopPrank();
        assertEq(IERC20(USDC).balanceOf(ALICE), 0);
        assertEq(IERC20(WAVAX).balanceOf(ALICE), WAVAX_AMOUNT);
    }

    function testSwapWithSlippageTolerance() public {
        deal(WAVAX, ALICE, WAVAX_AMOUNT);
        assertEq(IERC20(USDC).balanceOf(ALICE), 0);
        uint256 amountMinOut = WAVAX_AMOUNT * 98 / 100 * chainlinkPrice(CHAINLINK_AVAX) / chainlinkPrice(CHAINLINK_USDC) * 10 ** IERC20Metadata(USDC).decimals() / 10 ** IERC20Metadata(WAVAX).decimals();
        vm.startPrank(ALICE);
        IERC20(WAVAX).approve(address(dex), type(uint256).max);
        dex.swapSlippageMin(WAVAX_AMOUNT, amountMinOut, WAVAX, USDC, ALICE);
        vm.stopPrank();
        assertGt(IERC20(USDC).balanceOf(ALICE), amountMinOut);
        assertEq(IERC20(WAVAX).balanceOf(ALICE), 0);
    }

    function testSwapWithSlippageDoNotSwapIfAmountOutIsZero() public {
        deal(WAVAX, ALICE, WAVAX_AMOUNT);
        assertEq(IERC20(USDC).balanceOf(ALICE), 0);
        vm.startPrank(ALICE);
        IERC20(WAVAX).approve(address(dex), type(uint256).max);
        dex.swapSlippageMin(0, 0, WAVAX, USDC, ALICE);
        vm.stopPrank();
        assertEq(IERC20(USDC).balanceOf(ALICE), 0);
        assertEq(IERC20(WAVAX).balanceOf(ALICE), WAVAX_AMOUNT);
    }

    function testSwapWithTooLowSlippageToleranceFail() public {
        deal(WAVAX, ALICE, WAVAX_AMOUNT);
        assertEq(IERC20(USDC).balanceOf(ALICE), 0);
        uint256 amountMinOut = WAVAX_AMOUNT * chainlinkPrice(CHAINLINK_AVAX) / chainlinkPrice(CHAINLINK_USDC) * 10 ** IERC20Metadata(USDC).decimals() / 10 ** IERC20Metadata(WAVAX).decimals();
        vm.startPrank(ALICE);
        IERC20(WAVAX).approve(address(dex), type(uint256).max);
        vm.expectRevert(bytes("JoeRouter: INSUFFICIENT_OUTPUT_AMOUNT"));
        dex.swapSlippageMin(WAVAX_AMOUNT, amountMinOut, WAVAX, USDC, ALICE);
        vm.stopPrank();
    }

    /** rescue **/

    function testCanRescueToken() public {
        uint JOE_AMOUNT = 100 * 10 ** IERC20Metadata(JOE).decimals();
        deal(JOE, address(dex), JOE_AMOUNT);
        assertEq(IERC20(JOE).balanceOf(address(dex)), JOE_AMOUNT);
        vm.startPrank(OWNER);
        dex.rescueToken(JOE);
        vm.stopPrank();
        assertEq(IERC20(JOE).balanceOf(address(dex)), 0);
        assertEq(IERC20(JOE).balanceOf(OWNER), JOE_AMOUNT);
    }

    function testOnlyOwnerCanRescueToken() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        dex.rescueToken(WAVAX);
    }

    function testCanRescueNative() public {
        uint256 ownerBalanceBefore = OWNER.balance;
        deal(address(dex), WAVAX_AMOUNT);
        assertEq(address(dex).balance, WAVAX_AMOUNT);
        vm.prank(OWNER);
        dex.rescueNative();
        assertEq(address(dex).balance, 0);
        assertEq(OWNER.balance - ownerBalanceBefore, WAVAX_AMOUNT);
    }

    function testOnlyOwnerCanRescueNative() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        dex.rescueNative();
    }

    /** helper **/

    function chainlinkPrice(address asset) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(asset);

        (
        /*uint80 roundID*/,
        int price,
        /*uint startedAt*/,
        /*uint timeStamp*/,
        /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        return uint256(price);
    }

    function setNewRoute() internal {
        vm.prank(address(dex));
        IERC20(newRoute[0]).approve(TRADER_JOE_ROUTER, 0);
        vm.prank(OWNER);
        dex.setRoutes(newRoutes);
    }

}
