// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../../../contracts/interfaces/CloberMarketSwapCallbackReceiver.sol";
import "../../../../../contracts/interfaces/CloberOrderBook.sol";
import "../../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../../contracts/GeometricPriceBook.sol";
import "../../../../../contracts/OrderNFT.sol";
import "../../../../../contracts/OrderBook.sol";
import "../Constants.sol";

contract ClaimIntegrationTest is Test, CloberMarketSwapCallbackReceiver {
    using OrderKeyUtils for OrderKey;
    event ClaimOrder(
        address indexed claimer,
        address indexed user,
        uint64 rawAmount,
        uint256 bountyAmount,
        uint256 orderIndex,
        uint16 priceIndex,
        bool isBase
    );

    struct Vars {
        uint256 beforeNFTBalance;
        uint256 beforeETHBalance;
        uint256 beforeMakerBaseBalance;
        uint256 beforeMakerQuoteBalance;
        uint256 expectedClaimAmount;
        uint256 expectedMakerFee;
        uint256 expectedTakerFee;
        uint128 beforeQuoteFeeBalance;
        uint128 beforeBaseFeeBalance;
        uint128 afterQuoteFeeBalance;
        uint128 afterBaseFeeBalance;
    }

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

    function _expectFullyClaimed(
        address maker,
        uint64 expectClaimedRawAmount,
        OrderKey memory orderKey
    ) private {
        Vars memory vars;
        vars.beforeMakerBaseBalance = baseToken.balanceOf(maker);
        vars.beforeMakerQuoteBalance = quoteToken.balanceOf(maker);
        vars.beforeNFTBalance = orderToken.balanceOf(maker);
        vars.beforeETHBalance = receivedEthers;
        (vars.beforeQuoteFeeBalance, vars.beforeBaseFeeBalance) = market.getFeeBalance();

        uint256 roundedDownTakeAmount;
        if (orderKey.isBid) {
            vars.expectedClaimAmount = market.rawToBase(expectClaimedRawAmount, orderKey.priceIndex, false);
            roundedDownTakeAmount = market.rawToQuote(expectClaimedRawAmount);
        } else {
            vars.expectedClaimAmount = market.rawToQuote(expectClaimedRawAmount);
            roundedDownTakeAmount = market.rawToBase(expectClaimedRawAmount, orderKey.priceIndex, false);
        }
        // round up maker fee when makerFee is positive
        vars.expectedMakerFee = Math.divide(
            roundedDownTakeAmount * Constants.MAKE_FEE,
            Constants.FEE_PRECISION,
            market.makerFee() > 0
        );
        // calculate taker fee that protocol gained
        vars.expectedTakerFee = (roundedDownTakeAmount * Constants.TAKE_FEE) / Constants.FEE_PRECISION;

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(
                CloberOrderNFT.onBurn,
                (OrderKey(orderKey.isBid, orderKey.priceIndex, orderKey.orderIndex).encode())
            )
        );
        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            address(this),
            maker,
            expectClaimedRawAmount,
            Constants.CLAIM_BOUNTY * 1 gwei,
            orderKey.orderIndex,
            orderKey.priceIndex,
            orderKey.isBid
        );
        market.claim(address(this), _toArray(orderKey));

        (vars.afterQuoteFeeBalance, vars.afterBaseFeeBalance) = market.getFeeBalance();
        if (orderKey.isBid) {
            assertEq(
                baseToken.balanceOf(maker) - vars.beforeMakerBaseBalance,
                vars.expectedClaimAmount,
                "ERROR_BASE_BALANCE"
            );
            assertEq(
                quoteToken.balanceOf(maker) - vars.beforeMakerQuoteBalance,
                vars.expectedMakerFee,
                "ERROR_QUOTE_BALANCE"
            );
            assertEq(
                vars.afterQuoteFeeBalance - vars.beforeQuoteFeeBalance,
                vars.expectedTakerFee - vars.expectedMakerFee,
                "ERROR_PROTOCOL_FEE_QUOTE_BALANCE"
            );
        } else {
            assertEq(
                quoteToken.balanceOf(maker) - vars.beforeMakerQuoteBalance,
                vars.expectedClaimAmount,
                "ERROR_QUOTE_BALANCE"
            );
            assertEq(
                baseToken.balanceOf(maker) - vars.beforeMakerBaseBalance,
                vars.expectedMakerFee,
                "ERROR_BASE_BALANCE"
            );
            assertEq(
                vars.afterBaseFeeBalance - vars.beforeBaseFeeBalance,
                vars.expectedTakerFee - vars.expectedMakerFee,
                "ERROR_PROTOCOL_FEE_BASE_BALANCE"
            );
        }
        assertEq(receivedEthers - vars.beforeETHBalance, Constants.CLAIM_BOUNTY * 1 gwei, "ERROR_CLAIM_BOUNTY_BALANCE");
        assertEq(vars.beforeNFTBalance - orderToken.balanceOf(maker), 1, "ERROR_NFT_BALANCE");
    }

    function _expectPartiallyClaimed(
        address maker,
        uint64 expectClaimedRawAmount,
        OrderKey memory orderKey
    ) private {
        Vars memory vars;
        vars.beforeMakerBaseBalance = baseToken.balanceOf(maker);
        vars.beforeMakerQuoteBalance = quoteToken.balanceOf(maker);
        vars.beforeETHBalance = receivedEthers;
        (vars.beforeQuoteFeeBalance, vars.beforeBaseFeeBalance) = market.getFeeBalance();

        uint256 roundedDownTakeAmount;
        if (orderKey.isBid) {
            vars.expectedClaimAmount = market.rawToBase(expectClaimedRawAmount, orderKey.priceIndex, false);
            roundedDownTakeAmount = market.rawToQuote(expectClaimedRawAmount);
        } else {
            vars.expectedClaimAmount = market.rawToQuote(expectClaimedRawAmount);
            roundedDownTakeAmount = market.rawToBase(expectClaimedRawAmount, orderKey.priceIndex, false);
        }
        // round up maker fee when makerFee is positive
        vars.expectedMakerFee = Math.divide(
            roundedDownTakeAmount * Constants.MAKE_FEE,
            Constants.FEE_PRECISION,
            market.makerFee() > 0
        );
        // calculate taker fee that protocol gained
        vars.expectedTakerFee = (roundedDownTakeAmount * Constants.TAKE_FEE) / Constants.FEE_PRECISION;

        vm.expectEmit(true, true, true, true);
        emit ClaimOrder(
            address(this),
            maker,
            expectClaimedRawAmount,
            0,
            orderKey.orderIndex,
            orderKey.priceIndex,
            orderKey.isBid
        );
        market.claim(address(this), _toArray(orderKey));

        (vars.afterQuoteFeeBalance, vars.afterBaseFeeBalance) = market.getFeeBalance();
        if (orderKey.isBid) {
            assertEq(
                baseToken.balanceOf(maker) - vars.beforeMakerBaseBalance,
                vars.expectedClaimAmount,
                "ERROR_BASE_BALANCE"
            );
            assertEq(
                quoteToken.balanceOf(maker) - vars.beforeMakerQuoteBalance,
                vars.expectedMakerFee,
                "ERROR_QUOTE_BALANCE"
            );
            assertEq(
                vars.afterQuoteFeeBalance - vars.beforeQuoteFeeBalance,
                vars.expectedTakerFee - vars.expectedMakerFee,
                "ERROR_PROTOCOL_FEE_QUOTE_BALANCE"
            );
        } else {
            assertEq(
                quoteToken.balanceOf(maker) - vars.beforeMakerQuoteBalance,
                vars.expectedClaimAmount,
                "ERROR_QUOTE_BALANCE"
            );
            assertEq(
                baseToken.balanceOf(maker) - vars.beforeMakerBaseBalance,
                vars.expectedMakerFee,
                "ERROR_BASE_BALANCE"
            );
            assertEq(
                vars.afterBaseFeeBalance - vars.beforeBaseFeeBalance,
                vars.expectedTakerFee - vars.expectedMakerFee,
                "ERROR_PROTOCOL_FEE_BASE_BALANCE"
            );
        }
        assertEq(receivedEthers - vars.beforeETHBalance, 0, "ERROR_CLAIM_BOUNTY_BALANCE");
    }

    function _expectNothingClaimed(address maker, OrderKey memory orderKey) private {
        Vars memory vars;
        vars.beforeMakerBaseBalance = baseToken.balanceOf(maker);
        vars.beforeMakerQuoteBalance = quoteToken.balanceOf(maker);
        vars.beforeETHBalance = receivedEthers;
        (vars.beforeQuoteFeeBalance, vars.beforeBaseFeeBalance) = market.getFeeBalance();

        market.claim(address(this), _toArray(orderKey));

        (vars.afterQuoteFeeBalance, vars.afterBaseFeeBalance) = market.getFeeBalance();
        assertEq(baseToken.balanceOf(maker) - vars.beforeMakerBaseBalance, 0, "ERROR_BASE_BALANCE");
        assertEq(quoteToken.balanceOf(maker) - vars.beforeMakerQuoteBalance, 0, "ERROR_QUOTE_BALANCE");
        assertEq(receivedEthers - vars.beforeETHBalance, 0, "ERROR_CLAIM_BOUNTY_BALANCE");
        assertEq(vars.afterQuoteFeeBalance - vars.beforeQuoteFeeBalance, 0, "PROTOCOL_FEE_QUOTE_BALANCE");
        assertEq(vars.afterBaseFeeBalance - vars.beforeBaseFeeBalance, 0, "PROTOCOL_FEE_BASE_BALANCE");
    }

    function _toArray(OrderKey memory orderKey) private pure returns (OrderKey[] memory) {
        OrderKey[] memory ids = new OrderKey[](1);
        ids[0] = orderKey;
        return ids;
    }

    function testPartialClaimOfBidOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;

        // Make 12
        uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            12,
            0,
            1,
            new bytes(0)
        );

        // Take 0 -> 2 -> 0 -> 3 -> 0 -> 7
        // Take 0
        market.limitOrder(
            Constants.USER_B,
            priceIndex + 1,
            0,
            market.rawToBase(777, priceIndex + 1, true),
            0,
            new bytes(0)
        );
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 2
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(2, priceIndex, true), 0, new bytes(0));
        _expectPartiallyClaimed(
            Constants.USER_A,
            2,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );
        // Already claimed Order
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 0
        market.limitOrder(
            Constants.USER_B,
            priceIndex + 1,
            0,
            market.rawToBase(777, priceIndex + 1, true),
            0,
            new bytes(0)
        );
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 3
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(3, priceIndex, true), 0, new bytes(0));
        _expectPartiallyClaimed(
            Constants.USER_A,
            3,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );
        // Already claimed Order
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 0
        market.limitOrder(
            Constants.USER_B,
            priceIndex + 1,
            0,
            market.rawToBase(777, priceIndex + 1, true),
            0,
            new bytes(0)
        );
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 7
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(7, priceIndex, true), 0, new bytes(0));
        _expectFullyClaimed(
            Constants.USER_A,
            7,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Make 12
        orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            12,
            0,
            1,
            new bytes(0)
        );

        // Take 0 -> 7 -> 0 -> 3 -> 0 -> 2 -> 0
        // Take 0
        market.limitOrder(
            Constants.USER_B,
            priceIndex + 1,
            0,
            market.rawToBase(777, priceIndex + 1, true),
            0,
            new bytes(0)
        );
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 7
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(7, priceIndex, true), 0, new bytes(0));
        _expectPartiallyClaimed(
            Constants.USER_A,
            7,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 0
        market.limitOrder(
            Constants.USER_B,
            priceIndex + 1,
            0,
            market.rawToBase(777, priceIndex + 1, true),
            0,
            new bytes(0)
        );
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 3
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(3, priceIndex, true), 0, new bytes(0));
        _expectPartiallyClaimed(
            Constants.USER_A,
            3,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );
        // Already claimed Order
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 0
        market.limitOrder(
            Constants.USER_B,
            priceIndex + 1,
            0,
            market.rawToBase(777, priceIndex + 1, true),
            0,
            new bytes(0)
        );
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 2
        market.limitOrder(Constants.USER_B, priceIndex, 0, market.rawToBase(2, priceIndex, true), 0, new bytes(0));
        _expectFullyClaimed(
            Constants.USER_A,
            2,
            OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
        );
    }

    function testPartialClaimOfAskOrder() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;

        // Make 12
        uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            0,
            market.rawToBase(12, priceIndex, true),
            0,
            new bytes(0)
        );

        // Take 0 -> 2 -> 0 -> 3 -> 0 -> 7
        // Take 0
        market.limitOrder(Constants.USER_B, priceIndex - 1, 777, 0, 1, new bytes(0));
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 2
        market.limitOrder(Constants.USER_B, priceIndex, 2, 0, 1, new bytes(0));
        _expectPartiallyClaimed(
            Constants.USER_A,
            2,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );
        // Already claimed Order
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 0
        market.limitOrder(Constants.USER_B, priceIndex - 1, 777, 0, 1, new bytes(0));
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 3
        market.limitOrder(Constants.USER_B, priceIndex, 3, 0, 1, new bytes(0));
        _expectPartiallyClaimed(
            Constants.USER_A,
            3,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );
        // Already claimed Order
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 0
        market.limitOrder(Constants.USER_B, priceIndex - 1, 777, 0, 1, new bytes(0));
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 7
        market.limitOrder(Constants.USER_B, priceIndex, 7, 0, 1, new bytes(0));
        _expectFullyClaimed(
            Constants.USER_A,
            7,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Make 12
        orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
            Constants.USER_A,
            priceIndex,
            0,
            market.rawToBase(12, priceIndex, true),
            0,
            new bytes(0)
        );

        // Take 0 -> 7 -> 0 -> 3 -> 0 -> 2
        // Take 0
        market.limitOrder(Constants.USER_B, priceIndex - 1, 777, 0, 1, new bytes(0));
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 7
        market.limitOrder(Constants.USER_B, priceIndex, 7, 0, 1, new bytes(0));
        _expectPartiallyClaimed(
            Constants.USER_A,
            7,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 0
        market.limitOrder(Constants.USER_B, priceIndex - 1, 777, 0, 1, new bytes(0));
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 3
        market.limitOrder(Constants.USER_B, priceIndex, 3, 0, 1, new bytes(0));
        _expectPartiallyClaimed(
            Constants.USER_A,
            3,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 0
        market.limitOrder(Constants.USER_B, priceIndex - 1, 777, 0, 1, new bytes(0));
        _expectNothingClaimed(
            Constants.USER_A,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );

        // Take 2
        market.limitOrder(Constants.USER_B, priceIndex, 2, 0, 1, new bytes(0));
        _expectFullyClaimed(
            Constants.USER_A,
            2,
            OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
        );
    }

    function testClaimOnLargeBidOrderFlow() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < vm.envOr("LARGE_ORDER_COUNT", Constants.LARGE_ORDER_COUNT); i++) {
            // Make
            uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                777,
                0,
                1,
                new bytes(0)
            );

            // Take
            market.limitOrder(
                Constants.USER_B,
                priceIndex,
                0,
                market.rawToBase(777, priceIndex, true),
                0,
                new bytes(0)
            );

            _expectFullyClaimed(
                Constants.USER_A,
                777,
                OrderKey({isBid: Constants.BID, priceIndex: priceIndex, orderIndex: orderIndex})
            );
        }
    }

    function testClaimOnLargeAskOrderFlow() public {
        _createMarket(-int24(Constants.MAKE_FEE), Constants.TAKE_FEE);

        uint16 priceIndex = 3;
        for (uint256 i = 0; i < vm.envOr("LARGE_ORDER_COUNT", Constants.LARGE_ORDER_COUNT); i++) {
            // Make
            uint256 orderIndex = market.limitOrder{value: Constants.CLAIM_BOUNTY * 1 gwei}(
                Constants.USER_A,
                priceIndex,
                0,
                market.rawToBase(777, priceIndex, true),
                0,
                new bytes(0)
            );

            // Take
            market.limitOrder(Constants.USER_B, priceIndex, 777, 0, 1, new bytes(0));

            _expectFullyClaimed(
                Constants.USER_A,
                777,
                OrderKey({isBid: Constants.ASK, priceIndex: priceIndex, orderIndex: orderIndex})
            );
        }
    }
}
