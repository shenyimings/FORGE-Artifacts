// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

import "../../interfaces/CloberRouter.sol";
import "../../OrderCanceler.sol";
import "../../interfaces/CloberMarketSwapCallbackReceiver.sol";
import "../../Errors.sol";
import "../../interfaces/CloberMarketFactory.sol";

import "../../OrderBook.sol";

contract GasReporter {
    using SafeERC20 for IERC20;

    uint256 private constant _PRICE_PRECISION = 10**18;
    uint256 private constant _QUOTE_PRECISION_COMPLEMENT = 10**12; // 10**(18 - d)
    uint256 private constant _BASE_PRECISION_COMPLEMENT = 1; // 10**(18 - d)
    uint256 private constant _QUOTE_UNIT = 10000;

    CloberRouter private immutable _marketRouter;
    OrderBook private immutable _market;
    CloberMarketFactory private immutable _factory;
    OrderCanceler private immutable _orderCanceler;

    constructor(
        address marketRouter,
        address orderCanceler,
        address market,
        address factory
    ) {
        _marketRouter = CloberRouter(marketRouter);
        _market = OrderBook(market);
        _orderCanceler = OrderCanceler(orderCanceler);
        _factory = CloberMarketFactory(factory);
    }

    function limitBidOrder(
        address user,
        uint16 priceIndex,
        uint64 rawAmount,
        bool postOnly
    ) public payable returns (uint256) {
        return
            _marketRouter.limitBid{value: msg.value}(
                CloberRouter.LimitOrderParams({
                    market: address(_market),
                    deadline: uint64(block.timestamp + 100),
                    claimBounty: uint32(msg.value / 1 gwei),
                    user: user,
                    priceIndex: priceIndex,
                    rawAmount: rawAmount,
                    baseAmount: 0,
                    postOnly: postOnly,
                    useNative: false
                })
            );
    }

    function limitAskOrder(
        address user,
        uint16 priceIndex,
        uint256 baseAmount,
        bool postOnly
    ) public payable returns (uint256) {
        return
            _marketRouter.limitAsk{value: msg.value}(
                CloberRouter.LimitOrderParams({
                    market: address(_market),
                    deadline: uint64(block.timestamp + 100),
                    claimBounty: uint32(msg.value / 1 gwei),
                    user: user,
                    priceIndex: priceIndex,
                    rawAmount: 0,
                    baseAmount: baseAmount,
                    postOnly: postOnly,
                    useNative: false
                })
            );
    }

    function marketBidOrder(address user, uint64 rawAmount) public {
        _marketRouter.marketBid(
            CloberRouter.MarketOrderParams({
                market: address(_market),
                deadline: uint64(block.timestamp + 100),
                user: user,
                limitPriceIndex: type(uint16).max,
                rawAmount: rawAmount,
                baseAmount: 0,
                expendInput: true,
                useNative: false
            })
        );
    }

    function marketAskOrder(address user, uint256 baseAmount) public {
        _marketRouter.marketAsk(
            CloberRouter.MarketOrderParams({
                market: address(_market),
                deadline: uint64(block.timestamp + 100),
                user: user,
                limitPriceIndex: 0,
                rawAmount: 0,
                baseAmount: baseAmount,
                expendInput: true,
                useNative: false
            })
        );
    }

    function claimOrder(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) public {
        CloberRouter.ClaimOrderParams[] memory paramsList = new CloberRouter.ClaimOrderParams[](1);
        paramsList[0].market = address(_market);
        paramsList[0].orderKeys = new OrderKey[](1);
        paramsList[0].orderKeys[0] = OrderKey({isBid: isBid, priceIndex: priceIndex, orderIndex: orderIndex});

        _marketRouter.claim(uint64(block.timestamp + 100), paramsList);
    }

    function cancelOrder(uint256 tokenId) public {
        CloberOrderCanceler.CancelParams[] memory paramsList = new CloberOrderCanceler.CancelParams[](1);
        paramsList[0].market = address(_market);
        paramsList[0].tokenIds = new uint256[](1);
        paramsList[0].tokenIds[0] = tokenId;

        _orderCanceler.cancel(paramsList);
    }

    // EmptyHeapEmptyTree
    function EHET_LimitBid(
        address user,
        uint16 priceIndex,
        uint64 rawAmount
    ) external payable returns (uint256) {
        return limitBidOrder(user, priceIndex, rawAmount, false);
    }

    function EHET_LimitAsk(
        address user,
        uint16 priceIndex,
        uint256 baseAmount
    ) external payable returns (uint256) {
        return limitAskOrder(user, priceIndex, baseAmount, false);
    }

    function EHET_FullyMarketBid(address user, uint64 rawAmount) external payable {
        marketBidOrder(user, rawAmount);
    }

    function EHET_FullyMarketAsk(address user, uint256 baseAmount) external payable {
        marketAskOrder(user, baseAmount);
    }

    function EHET_PartiallyMarketBid(address user, uint64 rawAmount) external payable {
        marketBidOrder(user, rawAmount);
    }

    function EHET_PartiallyMarketAsk(address user, uint256 baseAmount) external payable {
        marketAskOrder(user, baseAmount);
    }

    function EHET_FullyClaimBid(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function EHET_FullyClaimAsk(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function EHET_PartiallyClaimBid(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function EHET_PartiallyClaimAsk(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function EHET_FullyCancelBid(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHET_FullyCancelAsk(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHET_PartiallyCancelBid(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHET_PartiallyCancelAsk(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHET_CancelRemainingBidOrder(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHET_CancelRemainingAskOrder(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    // EmptyHeapDirtyTree
    function EHDT_LimitBid(
        address user,
        uint16 priceIndex,
        uint64 rawAmount
    ) external payable returns (uint256) {
        return limitBidOrder(user, priceIndex, rawAmount, false);
    }

    function EHDT_LimitAsk(
        address user,
        uint16 priceIndex,
        uint256 baseAmount
    ) external payable returns (uint256) {
        return limitAskOrder(user, priceIndex, baseAmount, false);
    }

    function EHDT_FullyMarketBid(address user, uint64 rawAmount) external payable {
        marketBidOrder(user, rawAmount);
    }

    function EHDT_FullyMarketAsk(address user, uint256 baseAmount) external payable {
        marketAskOrder(user, baseAmount);
    }

    function EHDT_PartiallyMarketBid(address user, uint64 rawAmount) external payable {
        marketBidOrder(user, rawAmount);
    }

    function EHDT_PartiallyMarketAsk(address user, uint256 baseAmount) external payable {
        marketAskOrder(user, baseAmount);
    }

    function EHDT_FullyClaimBid(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function EHDT_FullyClaimAsk(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function EHDT_PartiallyClaimBid(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function EHDT_PartiallyClaimAsk(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function EHDT_FullyCancelBid(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHDT_FullyCancelAsk(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHDT_PartiallyCancelBid(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHDT_PartiallyCancelAsk(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHDT_CancelRemainingBidOrder(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function EHDT_CancelRemainingAskOrder(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    // FilledHeapEmptyTree
    function FHET_LimitBid(
        address user,
        uint16 priceIndex,
        uint64 rawAmount
    ) external payable returns (uint256) {
        return limitBidOrder(user, priceIndex, rawAmount, false);
    }

    function FHET_LimitAsk(
        address user,
        uint16 priceIndex,
        uint256 baseAmount
    ) external payable returns (uint256) {
        return limitAskOrder(user, priceIndex, baseAmount, false);
    }

    function FHET_FullyMarketBid(address user, uint64 rawAmount) external payable {
        marketBidOrder(user, rawAmount);
    }

    function FHET_FullyMarketAsk(address user, uint256 baseAmount) external payable {
        marketAskOrder(user, baseAmount);
    }

    function FHET_PartiallyMarketBid(address user, uint64 rawAmount) external payable {
        marketBidOrder(user, rawAmount);
    }

    function FHET_PartiallyMarketAsk(address user, uint256 baseAmount) external payable {
        marketAskOrder(user, baseAmount);
    }

    function FHET_FullyClaimBid(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function FHET_FullyClaimAsk(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function FHET_PartiallyClaimBid(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function FHET_PartiallyClaimAsk(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function FHET_FullyCancelBid(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHET_FullyCancelAsk(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHET_PartiallyCancelBid(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHET_PartiallyCancelAsk(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHET_CancelRemainingBidOrder(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHET_CancelRemainingAskOrder(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    // FilledHeapFilledTree
    function FHFT_LimitBid(
        address user,
        uint16 priceIndex,
        uint64 rawAmount
    ) external payable returns (uint256) {
        return limitBidOrder(user, priceIndex, rawAmount, false);
    }

    function FHFT_LimitAsk(
        address user,
        uint16 priceIndex,
        uint256 baseAmount
    ) external payable returns (uint256) {
        return limitAskOrder(user, priceIndex, baseAmount, false);
    }

    function FHFT_FullyMarketBid(address user, uint64 rawAmount) external payable {
        marketBidOrder(user, rawAmount);
    }

    function FHFT_FullyMarketAsk(address user, uint256 baseAmount) external payable {
        marketAskOrder(user, baseAmount);
    }

    function FHFT_PartiallyMarketBid(address user, uint64 rawAmount) external payable {
        marketBidOrder(user, rawAmount);
    }

    function FHFT_PartiallyMarketAsk(address user, uint256 baseAmount) external payable {
        marketAskOrder(user, baseAmount);
    }

    function FHFT_FullyClaimBid(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function FHFT_FullyClaimAsk(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function FHFT_PartiallyClaimBid(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function FHFT_PartiallyClaimAsk(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) external payable {
        claimOrder(isBid, priceIndex, orderIndex);
    }

    function FHFT_FullyCancelBid(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHFT_FullyCancelAsk(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHFT_PartiallyCancelBid(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHFT_PartiallyCancelAsk(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHFT_CancelRemainingBidOrder(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    function FHFT_CancelRemainingAskOrder(uint256 tokenId) external payable {
        cancelOrder(tokenId);
    }

    receive() external payable {}
}
