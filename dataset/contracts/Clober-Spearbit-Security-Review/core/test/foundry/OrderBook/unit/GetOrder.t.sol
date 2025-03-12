// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../contracts/mocks/MockPriceBook.sol";
import "../../../../contracts/OrderNFT.sol";
import "../../../../contracts/OrderBook.sol";
import "./Constants.sol";

contract OrderBookGetOrderUnitTest is Test, CloberMarketSwapCallbackReceiver {
    uint96 private constant _QUOTE_UNIT = 10**4; // unit is 1 USDC
    uint256 private constant _INIT_AMOUNT = 1000000000;
    address private constant _MAKER = address(0x12312);
    address private constant _MAKER2 = address(0x1231223);
    uint256 private constant _MAX_ORDER = 2**15; // 32768
    uint16 private constant _PRICE_INDEX = 100;
    uint16 private constant _RAW_AMOUNT = 1000;

    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook market;
    OrderNFT orderToken;

    uint256 orderIndex;

    function cloberMarketSwapCallback(
        address tokenIn,
        address,
        uint256 amountIn,
        uint256,
        bytes calldata
    ) external payable {
        IERC20(tokenIn).transfer(msg.sender, amountIn);
    }

    function setUp() public {
        orderToken = new OrderNFT(address(this), address(this));
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();
        market = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            _QUOTE_UNIT,
            int24(Constants.MAKE_FEE),
            Constants.TAKE_FEE,
            address(this),
            address(new MockPriceBook())
        );
        orderToken.init("", "", address(market));

        quoteToken.mint(address(this), 2 * _INIT_AMOUNT * 1e6);
        baseToken.mint(address(this), 2 * _INIT_AMOUNT * 1e18);
        quoteToken.approve(address(market), type(uint256).max);
        baseToken.approve(address(market), type(uint256).max);

        orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}({
            user: _MAKER,
            priceIndex: _PRICE_INDEX,
            rawAmount: _RAW_AMOUNT,
            baseAmount: 0,
            options: _buildLimitOrderOptions(Constants.BID, Constants.POST_ONLY),
            data: new bytes(0)
        });
    }

    function _buildLimitOrderOptions(bool isBid, bool postOnly) private pure returns (uint8) {
        return (isBid ? 1 : 0) + (postOnly ? 2 : 0);
    }

    function testGetOrder() public {
        CloberOrderBook.Order memory order = market.getOrder(OrderKey(Constants.BID, _PRICE_INDEX, orderIndex));
        assertEq(order.owner, _MAKER, "ORDER_OWNER");
        assertEq(order.claimBounty, Constants.CLAIM_BOUNTY, "CLAIM_BOUNTY");
        assertEq(order.amount, _RAW_AMOUNT, "ORDER_OPEN_AMOUNT");
    }

    function _fill() internal {
        vm.startPrank(_MAKER);
        OrderKey[] memory orderKeys = new OrderKey[](1);
        orderKeys[0] = OrderKey(Constants.BID, _PRICE_INDEX, orderIndex);
        market.cancel(_MAKER, orderKeys);
        vm.stopPrank();

        for (uint256 i = 0; i < _MAX_ORDER; i++) {
            market.limitOrder{value: Constants.CLAIM_BOUNTY * 2 * 1 gwei}({
                user: _MAKER2,
                priceIndex: _PRICE_INDEX,
                rawAmount: _RAW_AMOUNT * 2,
                baseAmount: 0,
                options: _buildLimitOrderOptions(Constants.BID, Constants.POST_ONLY),
                data: new bytes(0)
            });
        }
        orderIndex += _MAX_ORDER;
    }

    function testGetOrderWhenOrderIndexIsGreaterThanMaxOrder() public {
        _fill();
        CloberOrderBook.Order memory order = market.getOrder(OrderKey(Constants.BID, _PRICE_INDEX, orderIndex));
        assertEq(order.owner, _MAKER2, "ORDER_OWNER");
        assertEq(order.claimBounty, Constants.CLAIM_BOUNTY * 2, "CLAIM_BOUNTY");
        assertEq(order.amount, _RAW_AMOUNT * 2, "ORDER_OPEN_AMOUNT");
    }

    function testGetOrderWithInvalidOrderIndex() public {
        _fill();
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_ID));
        market.getOrder(OrderKey(Constants.BID, _PRICE_INDEX, orderIndex + _MAX_ORDER));
    }
}
