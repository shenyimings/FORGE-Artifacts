// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../contracts/mocks/MockPriceBook.sol";
import "../../../../contracts/interfaces/CloberOrderBook.sol";
import "../../../../contracts/OrderBook.sol";
import "../utils/MockReentrancyGuard.sol";
import "./Constants.sol";

contract OrderBookCallTypeUnitTest is Test {
    uint96 private constant _QUOTE_UNIT = 10**4; // unit is 1 USDC

    address proxy;

    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook market;

    function setUp() public {
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();
        market = new OrderBook(
            address(0x123),
            address(quoteToken),
            address(baseToken),
            _QUOTE_UNIT,
            int24(Constants.MAKE_FEE),
            Constants.TAKE_FEE,
            address(this),
            address(new MockPriceBook())
        );
        address unlockTemplate = address(new MockReentrancyGuard());
        proxy = address(new TransparentUpgradeableProxy(unlockTemplate, address(0x123), new bytes(0)));
        MockReentrancyGuard(proxy).unlock();
        vm.prank(address(0x123));
        TransparentUpgradeableProxy(payable(proxy)).upgradeTo(address(market));
    }

    function testDelegateCallToLimitOrder() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DELEGATE_CALL));
        CloberOrderBook(proxy).limitOrder(address(123), 1, 1, 1, 1, new bytes(0));
    }

    function testDelegateCallToMarketOrder() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DELEGATE_CALL));
        CloberOrderBook(proxy).marketOrder(address(123), 1, 1, 1, 1, new bytes(0));
    }

    function testDelegateCallToCancel() public {
        OrderKey[] memory params = new OrderKey[](1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DELEGATE_CALL));
        CloberOrderBook(proxy).cancel(address(this), params);
    }

    function testDelegateCallToClaim() public {
        OrderKey[] memory params = new OrderKey[](1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DELEGATE_CALL));
        CloberOrderBook(proxy).claim(address(this), params);
    }
}
