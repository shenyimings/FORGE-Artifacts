// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {SwapInfo} from "../src/interfaces/ISwapper.sol";
import {SpoolAccessControl} from "../src/access/SpoolAccessControl.sol";
import {Swapper, ExchangeNotAllowed, InvalidArrayLength, MissingRole, ROLE_SPOOL_ADMIN} from "../src/Swapper.sol";
import {Arrays} from "./libraries/Arrays.sol";
import {USD_DECIMALS_MULTIPLIER} from "./libraries/Constants.sol";
import {MockExchange} from "./mocks/MockExchange.sol";
import {MockPriceFeedManager} from "./mocks/MockPriceFeedManager.sol";
import {MockToken} from "./mocks/MockToken.sol";

contract SwapperTest is Test {
    event ExchangeAllowlistUpdated(address indexed exchange, bool isAllowed);

    address alice;
    address bob;
    address swapperAdmin;

    SpoolAccessControl accessControl;
    Swapper swapper;

    MockToken tokenA;
    MockToken tokenB;
    MockToken tokenC;

    MockExchange exchangeAB;
    MockExchange exchangeBC;

    function setUp() public {
        alice = address(0xa);
        bob = address(0xb);
        swapperAdmin = address(0xc);

        accessControl = new SpoolAccessControl();
        accessControl.initialize();

        accessControl.grantRole(ROLE_SPOOL_ADMIN, swapperAdmin);

        swapper = new Swapper(accessControl);

        tokenA = new MockToken("Token A", "TA");
        tokenB = new MockToken("Token B", "TB");
        tokenC = new MockToken("Token C", "TC");

        MockPriceFeedManager priceFeedManager = new MockPriceFeedManager();
        priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenB), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenC), 1 * USD_DECIMALS_MULTIPLIER);

        exchangeAB = new MockExchange(tokenA, tokenB, priceFeedManager);
        exchangeBC = new MockExchange(tokenB, tokenC, priceFeedManager);

        deal(address(tokenA), address(exchangeAB), 100 ether, true);
        deal(address(tokenB), address(exchangeAB), 100 ether, true);
        deal(address(tokenB), address(exchangeBC), 100 ether, true);
        deal(address(tokenC), address(exchangeBC), 100 ether, true);

        deal(address(tokenA), alice, 10 ether, true);
    }

    function test_updateExchangeAllowlist_shouldUpdateAllowlist() public {
        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(Arrays.toArray(address(0x1), address(0x2)), Arrays.toArray(true, true));
        vm.stopPrank();

        assertTrue(swapper.isExchangeAllowed(address(0x1)));
        assertTrue(swapper.isExchangeAllowed(address(0x2)));

        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(
            Arrays.toArray(address(0x1), address(0x2), address(0x3)), Arrays.toArray(false, false, true)
        );
        vm.stopPrank();

        assertFalse(swapper.isExchangeAllowed(address(0x1)));
        assertFalse(swapper.isExchangeAllowed(address(0x2)));
        assertTrue(swapper.isExchangeAllowed(address(0x3)));
    }

    function test_updateExchangesAllowlist_shouldEmitExchangeAllowlistUpdatedEvent() public {
        vm.expectEmit(true, true, true, true, address(swapper));
        emit ExchangeAllowlistUpdated(address(0x1), false);

        vm.expectEmit(true, true, true, true, address(swapper));
        emit ExchangeAllowlistUpdated(address(0x2), true);

        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(Arrays.toArray(address(0x1), address(0x2)), Arrays.toArray(false, true));
        vm.stopPrank();
    }

    function test_updateExchangeAllowlist_shouldRevertWhenArraysDoNotMatch() public {
        address[] memory exchanges = Arrays.toArray(address(0x1), address(0x2));
        bool[] memory allowed = Arrays.toArray(true);

        vm.expectRevert(InvalidArrayLength.selector);
        vm.prank(swapperAdmin);
        swapper.updateExchangeAllowlist(exchanges, allowed);

        allowed = Arrays.toArray(true, false, true);

        vm.expectRevert(InvalidArrayLength.selector);
        vm.prank(swapperAdmin);
        swapper.updateExchangeAllowlist(exchanges, allowed);
    }

    function test_updateExchangeAllowlist_shouldRevertWhenCalledByUnauthorizedAccount() public {
        address[] memory exchanges = Arrays.toArray(address(0x1), address(0x2));
        bool[] memory allowed = Arrays.toArray(true, true);

        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, alice));
        vm.prank(alice);
        swapper.updateExchangeAllowlist(exchanges, allowed);
    }

    function test_swap_shouldSwapCorrectly() public {
        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(
            Arrays.toArray(address(exchangeAB), address(exchangeBC)), Arrays.toArray(true, true)
        );
        vm.stopPrank();

        address[] memory tokens = Arrays.toArray(address(tokenA), address(tokenB), address(tokenC));

        SwapInfo[] memory swapInfo = new SwapInfo[](2);
        swapInfo[0] = SwapInfo({
            swapTarget: address(exchangeAB),
            token: address(tokenA),
            amountIn: 10 ether,
            swapCallData: abi.encodeWithSelector(exchangeAB.swap.selector, address(tokenA), 10 ether, address(swapper))
        });
        swapInfo[1] = SwapInfo({
            swapTarget: address(exchangeBC),
            token: address(tokenB),
            amountIn: 10 ether,
            swapCallData: abi.encodeWithSelector(exchangeBC.swap.selector, address(tokenB), 10 ether, bob)
        });

        vm.startPrank(alice);
        tokenA.transfer(address(swapper), 10 ether);
        swapper.swap(tokens, swapInfo, tokens, bob);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(alice), 0);
        assertEq(tokenC.balanceOf(bob), 10 ether);
    }

    function test_swap_shouldRevertWhenSwapReverts() public {
        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(
            Arrays.toArray(address(exchangeAB), address(exchangeBC)), Arrays.toArray(true, true)
        );
        vm.stopPrank();

        address[] memory tokens = Arrays.toArray(address(tokenA), address(tokenB), address(tokenC));

        SwapInfo[] memory swapInfo = new SwapInfo[](2);
        swapInfo[0] = SwapInfo({
            swapTarget: address(exchangeAB),
            token: address(tokenA),
            amountIn: 10 ether,
            swapCallData: abi.encodeWithSelector(exchangeAB.swap.selector, address(tokenA), 11 ether, address(swapper))
        });
        swapInfo[1] = SwapInfo({
            swapTarget: address(exchangeBC),
            token: address(tokenB),
            amountIn: 10 ether,
            swapCallData: abi.encodeWithSelector(exchangeBC.swap.selector, address(tokenB), 11 ether, bob)
        });

        vm.startPrank(alice);
        tokenA.transfer(address(swapper), 10 ether);

        vm.expectRevert();
        swapper.swap(tokens, swapInfo, tokens, bob);
        vm.stopPrank();
    }

    function test_swap_shouldReturnUnswappedTokens() public {
        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(
            Arrays.toArray(address(exchangeAB), address(exchangeBC)), Arrays.toArray(true, true)
        );
        vm.stopPrank();

        address[] memory tokens = Arrays.toArray(address(tokenA), address(tokenB), address(tokenC));

        SwapInfo[] memory swapInfo = new SwapInfo[](2);
        swapInfo[0] = SwapInfo({
            swapTarget: address(exchangeAB),
            token: address(tokenA),
            amountIn: 9 ether,
            swapCallData: abi.encodeWithSelector(exchangeAB.swap.selector, address(tokenA), 9 ether, address(swapper))
        });
        swapInfo[1] = SwapInfo({
            swapTarget: address(exchangeBC),
            token: address(tokenB),
            amountIn: 8 ether,
            swapCallData: abi.encodeWithSelector(exchangeBC.swap.selector, address(tokenB), 8 ether, address(swapper))
        });

        vm.startPrank(alice);
        tokenA.transfer(address(swapper), 10 ether);
        swapper.swap(tokens, swapInfo, tokens, bob);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(alice), 0);
        assertEq(tokenA.balanceOf(bob), 1 ether);
        assertEq(tokenB.balanceOf(bob), 1 ether);
        assertEq(tokenC.balanceOf(bob), 8 ether);
    }

    function test_swap_shouldRevertWhenExchangeIsNotAllowed() public {
        address[] memory tokens = Arrays.toArray(address(tokenA), address(tokenB));

        SwapInfo[] memory swapInfo = new SwapInfo[](1);
        swapInfo[0] = SwapInfo({
            swapTarget: address(exchangeAB),
            token: address(tokenA),
            amountIn: 10 ether,
            swapCallData: abi.encodeWithSelector(exchangeAB.swap.selector, address(tokenA), 10 ether, address(swapper))
        });

        vm.startPrank(alice);
        tokenA.transfer(address(swapper), 10 ether);
        vm.expectRevert(abi.encodeWithSelector(ExchangeNotAllowed.selector, address(exchangeAB)));
        swapper.swap(tokens, swapInfo, tokens, bob);
        vm.stopPrank();
    }
}
