// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/interfaces/CloberMarketSwapCallbackReceiver.sol";
import "../../../contracts/mocks/MockQuoteToken.sol";
import "../../../contracts/mocks/MockBaseToken.sol";
import "../../../contracts/OrderNFT.sol";
import "../../../contracts/MarketFactory.sol";
import "../../../contracts/MarketRouter.sol";
import "./OrderBookUtils.sol";
import "./GasReportUtils.sol";

contract EmptyHeapEmptyTreeTestMarketOrderGasReport is Test {
    address public constant MAKER = address(1);
    address public constant TAKER = address(2);
    uint16 public constant PRICE_INDEX_ASK = 567;
    uint16 public constant PRICE_INDEX_BID = 485;

    OrderBookUtils public orderBookUtils;
    OrderBook market;
    GasReporter gasReporter;
    address quoteToken;
    address baseToken;

    uint256 fullyFilledBidOrderId;
    uint256 partiallyFilledBidOrderId;
    uint256 openBidOrderId;

    uint256 fullyFilledAskOrderId;
    uint256 partiallyFilledAskOrderId;
    uint256 openAskOrderId;

    function setUp() public {
        orderBookUtils = new OrderBookUtils();
        orderBookUtils.createMarket();

        market = orderBookUtils.market();
        gasReporter = orderBookUtils.gasReporter();
        quoteToken = orderBookUtils.quoteToken();
        baseToken = orderBookUtils.baseToken();

        orderBookUtils.mintToken(MAKER);
        orderBookUtils.mintToken(TAKER);
        orderBookUtils.approveGasReporter(MAKER);
        orderBookUtils.approveRouter();

        uint64 rawAmount = 100;
        uint256 baseAmount = GasReportUtils.rawToBase(market, rawAmount, PRICE_INDEX_ASK, true);

        vm.startPrank(MAKER);
        IERC20(quoteToken).transfer(address(gasReporter), GasReportUtils.rawToQuote(rawAmount * 3));
        fullyFilledBidOrderId = gasReporter.limitBidOrder(MAKER, PRICE_INDEX_BID, rawAmount, true);
        partiallyFilledBidOrderId = gasReporter.limitBidOrder(MAKER, PRICE_INDEX_BID, rawAmount, true);
        openBidOrderId = gasReporter.limitBidOrder(MAKER, PRICE_INDEX_BID, rawAmount, true);

        IERC20(baseToken).transfer(address(gasReporter), baseAmount * 3);
        fullyFilledAskOrderId = gasReporter.limitAskOrder(MAKER, PRICE_INDEX_ASK, baseAmount, true);
        partiallyFilledAskOrderId = gasReporter.limitAskOrder(MAKER, PRICE_INDEX_ASK, baseAmount, true);
        openAskOrderId = gasReporter.limitAskOrder(MAKER, PRICE_INDEX_ASK, baseAmount, true);
        vm.stopPrank();
    }

    function testGasReport() public {
        uint256 snapshotId = vm.snapshot();
        orderBookUtils.marketBidOrder(
            TAKER,
            GasReportUtils.rawToQuote(orderBookUtils.getDepth(false, PRICE_INDEX_ASK)),
            gasReporter.EHET_FullyMarketBid
        );
        assertEq(orderBookUtils.getDepth(false, PRICE_INDEX_ASK), 0, "DEPTH_HAS_TO_BE_EMPTY");

        vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
        orderBookUtils.marketAskOrder(
            TAKER,
            GasReportUtils.rawToBase(
                market,
                orderBookUtils.getDepth(true, PRICE_INDEX_BID),
                orderBookUtils.bestPriceIndex(true),
                false
            ),
            gasReporter.EHET_FullyMarketAsk
        );
        assertEq(orderBookUtils.getDepth(false, PRICE_INDEX_BID), 0, "DEPTH_HAS_TO_BE_EMPTY");

        vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
        orderBookUtils.marketBidOrder(
            TAKER,
            GasReportUtils.rawToQuote(orderBookUtils.getDepth(false, PRICE_INDEX_ASK) / 2),
            gasReporter.EHET_PartiallyMarketBid
        );

        vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
        orderBookUtils.marketAskOrder(
            TAKER,
            GasReportUtils.rawToBase(
                market,
                orderBookUtils.getDepth(true, PRICE_INDEX_BID) / 2,
                orderBookUtils.bestPriceIndex(true),
                false
            ),
            gasReporter.EHET_PartiallyMarketAsk
        );
    }
}
