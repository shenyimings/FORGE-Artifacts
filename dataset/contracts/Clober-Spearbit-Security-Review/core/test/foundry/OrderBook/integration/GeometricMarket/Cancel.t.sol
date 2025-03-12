// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../../../contracts/interfaces/CloberMarketSwapCallbackReceiver.sol";
import "../../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../../contracts/GeometricPriceBook.sol";
import "../../../../../contracts/OrderNFT.sol";
import "../../../../../contracts/OrderBook.sol";
import "../Constants.sol";

contract CancelIntegrationTest is Test, CloberMarketSwapCallbackReceiver {
    using OrderKeyUtils for OrderKey;
    event CancelOrder(address indexed user, uint64 rawAmount, uint256 orderIndex, uint16 priceIndex, bool isBid);

    struct Return {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 refundBounty;
    }

    uint256 receivedEthers;
    MockQuoteToken quoteToken;
    MockBaseToken baseToken;
    OrderBook market;
    OrderNFT orderToken;

    mapping(uint16 => uint256[2]) bidOrderIndices;
    mapping(uint16 => uint256[2]) askOrderIndices;

    function setUp() public {
        quoteToken = new MockQuoteToken();
        baseToken = new MockBaseToken();
        receivedEthers = 0;
    }

    receive() external payable {
        receivedEthers += msg.value;
    }

    function cloberMarketSwapCallback(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata data
    ) external payable {
        tokenOut;
        amountOut;
        data;

        IERC20(tokenIn).transfer(msg.sender, amountIn);
    }

    function _createMarket(int24 makerFee, uint24 takerFee) private {
        orderToken = new OrderNFT(address(this), address(this));
        market = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            10**4,
            makerFee,
            takerFee,
            address(this),
            address(new GeometricPriceBook(Constants.GEOMETRIC_A, Constants.GEOMETRIC_R))
        );
        orderToken.init("", "", address(market));

        quoteToken.mint(address(this), type(uint128).max);
        quoteToken.approve(address(market), type(uint256).max);

        baseToken.mint(address(this), type(uint128).max);
        baseToken.approve(address(market), type(uint256).max);
    }

    function _toArray(OrderKey memory orderKey) private pure returns (OrderKey[] memory) {
        OrderKey[] memory ids = new OrderKey[](1);
        ids[0] = orderKey;
        return ids;
    }

    function testCancelFullyFilledBidOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            100,
            0,
            1,
            new bytes(0)
        );
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(100, priceIndex, true), 0, new bytes(0));

        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.USER_A);
        uint256 beforeETHBalance = address(Constants.USER_A).balance;
        uint256 beforeMakerQuoteBalance = quoteToken.balanceOf(Constants.USER_A);
        uint256 beforeMakerBaseBalance = baseToken.balanceOf(Constants.USER_A);
        uint256 expectedClaimedAmount = market.rawToBase(100, priceIndex, false);
        uint256 expectedTakeAmount = market.rawToQuote(100);

        uint256 minusFee = (expectedTakeAmount * Constants.MAKE_FEE) / Constants.FEE_PRECISION;
        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.BID, priceIndex, orderIndex).encode()))
        );
        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex}))
        );
        assertEq(quoteToken.balanceOf(Constants.USER_A) - beforeMakerQuoteBalance, minusFee, "ERROR_QUOTE_BALANCE");
        assertEq(
            baseToken.balanceOf(Constants.USER_A) - beforeMakerBaseBalance,
            expectedClaimedAmount,
            "ERROR_BASE_BALANCE"
        );
        assertEq(
            address(Constants.USER_A).balance - beforeETHBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY_BALANCE"
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.USER_A), 1, "ERROR_NFT_BALANCE");
    }

    function testCancelFullyFilledAskOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            0,
            market.rawToBase(100, priceIndex, true),
            0,
            new bytes(0)
        );
        market.limitOrder(Constants.USER_B, priceIndex, 100, 0, 1, new bytes(0));

        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.USER_A);
        uint256 beforeETHBalance = address(Constants.USER_A).balance;
        uint256 beforeMakerQuoteBalance = quoteToken.balanceOf(Constants.USER_A);
        uint256 beforeMakerBaseBalance = baseToken.balanceOf(Constants.USER_A);
        uint256 expectedClaimedAmount = market.rawToQuote(100);
        uint256 expectedTakeAmount = market.rawToBase(100, priceIndex, false);

        uint256 minusFee = (expectedTakeAmount * Constants.MAKE_FEE) / Constants.FEE_PRECISION;
        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.ASK, priceIndex, orderIndex).encode()))
        );
        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex}))
        );
        assertEq(baseToken.balanceOf(Constants.USER_A) - beforeMakerBaseBalance, minusFee, "ERROR_BASE_BALANCE");
        assertEq(
            quoteToken.balanceOf(Constants.USER_A) - beforeMakerQuoteBalance,
            expectedClaimedAmount,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            address(Constants.USER_A).balance - beforeETHBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY_BALANCE"
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.USER_A), 1, "ERROR_NFT_BALANCE");
    }

    function testCancelPartiallyFilledBidOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            100,
            0,
            1,
            new bytes(0)
        );
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(50, priceIndex, true), 0, new bytes(0));

        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.USER_A);
        uint256 beforeETHBalance = address(Constants.USER_A).balance;
        uint256 beforeMakerQuoteBalance = quoteToken.balanceOf(Constants.USER_A);
        uint256 beforeMakerBaseBalance = baseToken.balanceOf(Constants.USER_A);
        uint256 expectedClaimedAmount = market.rawToBase(50, priceIndex, false);
        uint256 expectedTakeAmount = market.rawToQuote(50);

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.BID, priceIndex, orderIndex).encode()))
        );
        vm.expectEmit(true, true, true, true);
        emit CancelOrder(Constants.USER_A, 50, orderIndex, priceIndex, Constants.BID);
        uint256 minusFee = (expectedTakeAmount * Constants.MAKE_FEE) / Constants.FEE_PRECISION;
        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex}))
        );
        assertEq(
            quoteToken.balanceOf(Constants.USER_A) - beforeMakerQuoteBalance,
            expectedTakeAmount + minusFee,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            baseToken.balanceOf(Constants.USER_A) - beforeMakerBaseBalance,
            expectedClaimedAmount,
            "ERROR_BASE_BALANCE"
        );
        assertEq(
            address(Constants.USER_A).balance - beforeETHBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY_BALANCE"
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.USER_A), 1, "ERROR_NFT_BALANCE");
    }

    function testCancelPartiallyFilledAskOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            0,
            market.rawToBase(100, priceIndex, true),
            0,
            new bytes(0)
        );
        market.limitOrder(Constants.USER_B, priceIndex, 50, 0, 1, new bytes(0));

        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.USER_A);
        uint256 beforeETHBalance = address(Constants.USER_A).balance;
        uint256 beforeMakerQuoteBalance = quoteToken.balanceOf(Constants.USER_A);
        uint256 beforeMakerBaseBalance = baseToken.balanceOf(Constants.USER_A);
        uint256 expectedClaimedAmount = market.rawToQuote(50);
        uint256 expectedTakeAmount = market.rawToBase(50, priceIndex, false);

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.ASK, priceIndex, orderIndex).encode()))
        );
        vm.expectEmit(true, true, true, true);
        emit CancelOrder(Constants.USER_A, 50, orderIndex, priceIndex, Constants.ASK);
        uint256 minusFee = (expectedTakeAmount * Constants.MAKE_FEE) / Constants.FEE_PRECISION;
        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex}))
        );
        assertEq(
            baseToken.balanceOf(Constants.USER_A) - beforeMakerBaseBalance,
            expectedTakeAmount + minusFee,
            "ERROR_BASE_BALANCE"
        );
        assertEq(
            quoteToken.balanceOf(Constants.USER_A) - beforeMakerQuoteBalance,
            expectedClaimedAmount,
            "ERROR_QUOTE_BALANCE"
        );
        assertEq(
            address(Constants.USER_A).balance - beforeETHBalance,
            Constants.CLAIM_BOUNTY * 1 gwei,
            "ERROR_CLAIM_BOUNTY_BALANCE"
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.USER_A), 1, "ERROR_NFT_BALANCE");
    }

    function testCancelClaimedBidOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            100,
            0,
            1,
            new bytes(0)
        );
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(100, priceIndex, true), 0, new bytes(0));
        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.USER_A);
        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.BID, priceIndex, orderIndex).encode()))
        );
        market.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex}))
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.USER_A), 1, "ERROR_NFT_BALANCE");

        uint256 beforeETHBalance = address(Constants.USER_A).balance;
        uint256 beforeMakerQuoteBalance = quoteToken.balanceOf(Constants.USER_A);
        uint256 beforeMakerBaseBalance = baseToken.balanceOf(Constants.USER_A);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex}))
        );
        assertEq(quoteToken.balanceOf(Constants.USER_A) - beforeMakerQuoteBalance, 0, "ERROR_QUOTE_BALANCE");
        assertEq(baseToken.balanceOf(Constants.USER_A) - beforeMakerBaseBalance, 0, "ERROR_BASE_BALANCE");
        assertEq(address(Constants.USER_A).balance - beforeETHBalance, 0, "ERROR_CLAIM_BOUNTY_BALANCE");
    }

    function testCancelClaimedAskOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            0,
            market.rawToBase(100, priceIndex, true),
            0,
            new bytes(0)
        );
        market.limitOrder(Constants.USER_B, priceIndex, 100, 0, 1, new bytes(0));
        uint256 beforeNFTBalance = orderToken.balanceOf(Constants.USER_A);
        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.ASK, priceIndex, orderIndex).encode()))
        );
        market.claim(
            address(this),
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex}))
        );
        assertEq(beforeNFTBalance - orderToken.balanceOf(Constants.USER_A), 1, "ERROR_NFT_BALANCE");

        uint256 beforeETHBalance = address(Constants.USER_A).balance;
        uint256 beforeMakerQuoteBalance = quoteToken.balanceOf(Constants.USER_A);
        uint256 beforeMakerBaseBalance = baseToken.balanceOf(Constants.USER_A);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex}))
        );
        assertEq(quoteToken.balanceOf(Constants.USER_A) - beforeMakerQuoteBalance, 0, "ERROR_QUOTE_BALANCE");
        assertEq(baseToken.balanceOf(Constants.USER_A) - beforeMakerBaseBalance, 0, "ERROR_BASE_BALANCE");
        assertEq(address(Constants.USER_A).balance - beforeETHBalance, 0, "ERROR_CLAIM_BOUNTY_BALANCE");
    }

    function testHighestBidPriceAfterCancel() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        for (uint16 price = 7; ; price -= 2) {
            for (uint256 orderIndex = 0; orderIndex < 2; orderIndex++) {
                bidOrderIndices[price][orderIndex] = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                    Constants.USER_A,
                    price,
                    100,
                    0,
                    1,
                    new bytes(0)
                );
            }
            if (price == 1) break;
        }

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 7, orderIndex: bidOrderIndices[7][0]}))
        );
        assertEq(market.bestPriceIndex(Constants.BID), 7);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 7, orderIndex: bidOrderIndices[7][1]}))
        );
        assertEq(market.bestPriceIndex(Constants.BID), 5);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 3, orderIndex: bidOrderIndices[3][0]}))
        );
        assertEq(market.bestPriceIndex(Constants.BID), 5);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 3, orderIndex: bidOrderIndices[3][1]}))
        );
        assertEq(market.bestPriceIndex(Constants.BID), 5);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 5, orderIndex: bidOrderIndices[5][0]}))
        );
        assertEq(market.bestPriceIndex(Constants.BID), 5);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 5, orderIndex: bidOrderIndices[5][1]}))
        );
        assertEq(market.bestPriceIndex(Constants.BID), 1);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 1, orderIndex: bidOrderIndices[1][0]}))
        );
        assertEq(market.bestPriceIndex(Constants.BID), 1);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.BID, priceIndex: 1, orderIndex: bidOrderIndices[1][1]}))
        );
        vm.expectRevert(abi.encodeWithSelector(OctopusHeap.OctopusHeapError.selector, 1)); // HEAP_EMPTY_ERROR
        market.bestPriceIndex(Constants.BID);
    }

    function testLowestAskPriceAfterCancel() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        for (uint16 price = 7; ; price -= 2) {
            for (uint256 orderIndex = 0; orderIndex < 2; orderIndex++) {
                askOrderIndices[price][orderIndex] = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                    Constants.USER_A,
                    price,
                    0,
                    market.rawToBase(100, price, true),
                    0,
                    new bytes(0)
                );
            }
            if (price == 1) break;
        }

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 1, orderIndex: askOrderIndices[1][0]}))
        );
        assertEq(market.bestPriceIndex(Constants.ASK), 1);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 1, orderIndex: askOrderIndices[1][1]}))
        );
        assertEq(market.bestPriceIndex(Constants.ASK), 3);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 5, orderIndex: askOrderIndices[5][0]}))
        );
        assertEq(market.bestPriceIndex(Constants.ASK), 3);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 5, orderIndex: askOrderIndices[5][1]}))
        );
        assertEq(market.bestPriceIndex(Constants.ASK), 3);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 3, orderIndex: askOrderIndices[3][0]}))
        );
        assertEq(market.bestPriceIndex(Constants.ASK), 3);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 3, orderIndex: askOrderIndices[3][1]}))
        );
        assertEq(market.bestPriceIndex(Constants.ASK), 7);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 7, orderIndex: askOrderIndices[7][0]}))
        );
        assertEq(market.bestPriceIndex(Constants.ASK), 7);

        vm.prank(Constants.USER_A);
        market.cancel(
            Constants.USER_A,
            _toArray(OrderKey({isBid: Constants.ASK, priceIndex: 7, orderIndex: askOrderIndices[7][1]}))
        );
        vm.expectRevert(abi.encodeWithSelector(OctopusHeap.OctopusHeapError.selector, 1)); // HEAP_EMPTY_ERROR
        market.bestPriceIndex(Constants.ASK);
    }

    function testCancelOnLargeBidOrderFlow() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < vm.envOr("LARGE_ORDER_COUNT", Constants.LARGE_ORDER_COUNT); i++) {
            uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                100,
                0,
                1,
                new bytes(0)
            );

            vm.expectCall(
                address(orderToken),
                abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.BID, priceIndex, orderIndex).encode()))
            );
            vm.prank(Constants.USER_A);
            emit CancelOrder(Constants.USER_A, 100, orderIndex, priceIndex, Constants.BID);
            market.cancel(
                Constants.USER_A,
                _toArray(OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex}))
            );
        }
    }

    function testCancelOnLargeAskOrderFlow() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < vm.envOr("LARGE_ORDER_COUNT", Constants.LARGE_ORDER_COUNT); i++) {
            uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                0,
                market.rawToBase(100, priceIndex, true),
                0,
                new bytes(0)
            );

            vm.expectCall(
                address(orderToken),
                abi.encodeCall(CloberOrderNFT.onBurn, (OrderKey(Constants.ASK, priceIndex, orderIndex).encode()))
            );
            vm.prank(Constants.USER_A);
            emit CancelOrder(Constants.USER_A, 100, orderIndex, priceIndex, Constants.ASK);
            market.cancel(
                Constants.USER_A,
                _toArray(OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex}))
            );
        }
    }
}
