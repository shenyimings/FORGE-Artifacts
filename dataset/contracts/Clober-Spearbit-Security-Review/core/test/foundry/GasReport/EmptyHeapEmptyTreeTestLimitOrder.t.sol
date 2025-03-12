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

contract EmptyHeapEmptyTreeTestLimitOrderGasReport is Test {
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
    }

    function testGasReport() public {
        uint256 snapshotId = vm.snapshot();
        snapshotId = vm.snapshot();
        orderBookUtils.limitBidOrder(MAKER, PRICE_INDEX_BID, 30 * 10**18, gasReporter.EHET_LimitBid);

        vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
        orderBookUtils.limitAskOrder(MAKER, PRICE_INDEX_ASK, 30 * 10**18, gasReporter.EHET_LimitAsk);
    }
}
