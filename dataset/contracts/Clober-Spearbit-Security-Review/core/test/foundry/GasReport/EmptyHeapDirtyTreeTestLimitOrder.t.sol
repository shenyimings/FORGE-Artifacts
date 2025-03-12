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

contract EmptyHeapDirtyTreeTestLimitOrderGasReport is Test {
    address public constant MAKER = address(1);
    address public constant TAKER = address(2);
    uint16 public constant PRICE_INDEX_ASK = 567;
    uint16 public constant PRICE_INDEX_BID = 485;

    OrderBookUtils public orderBookUtils;
    OrderBook market;
    GasReporter gasReporter;
    address quoteToken;
    address baseToken;

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
        for (uint256 orderIndex = 0; orderIndex < GasReportUtils.MAX_ORDER; orderIndex++) {
            IERC20(quoteToken).transfer(address(gasReporter), GasReportUtils.rawToQuote(rawAmount));
            gasReporter.limitBidOrder(MAKER, PRICE_INDEX_BID, rawAmount, true);
            IERC20(baseToken).transfer(address(gasReporter), baseAmount);
            gasReporter.limitAskOrder(MAKER, PRICE_INDEX_ASK, baseAmount, true);
            gasReporter.cancelOrder(GasReportUtils.encodeId(true, PRICE_INDEX_BID, orderIndex));
            gasReporter.cancelOrder(GasReportUtils.encodeId(false, PRICE_INDEX_ASK, orderIndex));
        }
        vm.stopPrank();
    }

    function testGasReport() public {
        uint256 snapshotId = vm.snapshot();
        snapshotId = vm.snapshot();
        orderBookUtils.limitBidOrder(MAKER, PRICE_INDEX_BID, 30 * 10**18, gasReporter.EHDT_LimitBid);

        vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
        orderBookUtils.limitAskOrder(MAKER, PRICE_INDEX_ASK, 30 * 10**18, gasReporter.EHDT_LimitAsk);
    }
}
