// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@clober/library/contracts/Create1.sol";
import "../../../contracts/MarketFactory.sol";
import "../../../contracts/MarketRouter.sol";
import "../../../contracts/mocks/MockERC20.sol";
import "../../../contracts/mocks/MockWETH.sol";
import "../../../contracts/MarketDeployer.sol";
import "../../../contracts/PriceBookDeployer.sol";
import "../../../contracts/OrderNFTDeployer.sol";
import "../../../contracts/OrderCanceler.sol";

contract MarketRouterUnitTest is Test {
    bool constant USE_NATIVE = true;
    bool constant EXPEND_INPUT = true;
    bool constant BID = true;
    bool constant ASK = false;
    bool constant POST_ONLY = true;
    uint96 constant QUOTE_UNIT = 10000;
    int24 constant MAKE_FEE = -1000;
    uint24 constant TAKE_FEE = 2000;
    address constant USER = address(0xabc);
    uint256 INIT_AMOUNT = 10**18;
    uint32 CLAIM_BOUNTY = 1000;
    uint16 PRICE_INDEX = 20000;

    address quoteToken;
    address payable baseToken;

    MarketFactory factory;
    MarketDeployer marketDeployer;
    PriceBookDeployer priceBookDeployer;
    OrderNFTDeployer orderTokenDeployer;
    OrderCanceler orderCanceler;

    MarketRouter router;

    CloberOrderBook market1;
    CloberOrderBook market2;
    CloberOrderNFT orderToken1;
    CloberOrderNFT orderToken2;

    // Set this var to act like an OrderBook due to the Router use this function.
    uint256 public marketId;

    function setUp() public {
        uint64 thisNonce = vm.getNonce(address(this));
        factory = new MarketFactory(
            Create1.computeAddress(address(this), thisNonce + 1),
            Create1.computeAddress(address(this), thisNonce + 2),
            Create1.computeAddress(address(this), thisNonce + 3),
            address(this),
            address(this),
            new address[](0)
        );
        marketDeployer = new MarketDeployer(address(factory));
        priceBookDeployer = new PriceBookDeployer(address(factory));
        orderTokenDeployer = new OrderNFTDeployer(address(factory), address(this));

        quoteToken = address(new MockERC20("quote", "QUOTE", 6));
        baseToken = payable(address(new MockWETH()));

        factory.registerQuoteToken(quoteToken);
        market1 = CloberOrderBook(
            factory.createStableMarket(
                address(this),
                quoteToken,
                baseToken,
                QUOTE_UNIT,
                MAKE_FEE,
                TAKE_FEE,
                10**14,
                10**14
            )
        );
        market2 = CloberOrderBook(
            factory.createVolatileMarket(
                address(this),
                quoteToken,
                baseToken,
                QUOTE_UNIT,
                MAKE_FEE,
                TAKE_FEE,
                10**10,
                1001 * 10**15
            )
        );
        orderToken1 = CloberOrderNFT(market1.orderToken());
        orderToken2 = CloberOrderNFT(market2.orderToken());
        router = new MarketRouter(address(factory));

        MockERC20(quoteToken).mint(USER, INIT_AMOUNT * 10**6);
        vm.deal(USER, INIT_AMOUNT * 10**18);
        vm.prank(USER);
        MockWETH(baseToken).deposit{value: INIT_AMOUNT * 10**18}();
        vm.prank(USER);
        IERC20(quoteToken).approve(address(router), INIT_AMOUNT * 10**6);
        vm.prank(USER);
        IERC20(baseToken).approve(address(router), INIT_AMOUNT * 10**18);
    }

    function _deployNewRouter() private returns (MarketRouter) {
        uint64 thisNonce = vm.getNonce(address(this));
        MarketFactory newFactory = new MarketFactory(
            Create1.computeAddress(address(this), thisNonce + 4),
            Create1.computeAddress(address(this), thisNonce + 5),
            Create1.computeAddress(address(this), thisNonce + 6),
            address(this),
            address(this),
            new address[](0)
        );
        newFactory.registerQuoteToken(quoteToken);

        MarketRouter newRouter = new MarketRouter(address(newFactory));
        vm.prank(USER);
        IERC20(quoteToken).approve(address(newRouter), INIT_AMOUNT * 10**6);
        vm.prank(USER);
        IERC20(baseToken).approve(address(newRouter), INIT_AMOUNT * 10**18);
        return newRouter;
    }

    function testCloberMarketSwapCallback() public {
        uint256 beforeRouterETHBalance = address(router).balance;
        uint256 beforeUserTokenBalance = IERC20(quoteToken).balanceOf(USER);
        uint256 beforeMarketTokenBalance = IERC20(quoteToken).balanceOf(address(market1));
        uint256 requestedQuote = 10;
        vm.prank(address(market1));
        vm.deal(address(market1), uint256(CLAIM_BOUNTY) * 1 gwei);
        router.cloberMarketSwapCallback{value: uint256(CLAIM_BOUNTY) * 1 gwei}(
            quoteToken,
            baseToken,
            requestedQuote,
            10,
            abi.encode(USER, !USE_NATIVE, 0)
        );
        uint256 userTokenDiff = beforeUserTokenBalance - IERC20(quoteToken).balanceOf(USER);
        uint256 marketTokenDiff = IERC20(quoteToken).balanceOf(address(market1)) - beforeMarketTokenBalance;
        uint256 routerETHDiff = address(router).balance - beforeRouterETHBalance;
        assertEq(userTokenDiff, marketTokenDiff);
        assertEq(userTokenDiff, requestedQuote);
        assertEq(routerETHDiff, uint256(CLAIM_BOUNTY) * 1 gwei);
    }

    function testCloberMarketSwapCallbackUsingNative() public {
        uint256 beforeWETHBalance = baseToken.balance;
        uint256 beforeUserBaseAmount = IERC20(baseToken).balanceOf(USER);
        uint256 inputAmount = 12312421;
        vm.deal(address(router), inputAmount);
        vm.expectCall(baseToken, inputAmount, abi.encodeCall(IWETH.deposit, ()));
        vm.prank(address(market1));
        router.cloberMarketSwapCallback(
            baseToken, // WETH
            quoteToken,
            inputAmount,
            10,
            abi.encode(USER, USE_NATIVE, 0)
        );
        assertEq(address(router).balance, 0, "ROUTER_BALANCE");
        assertEq(address(baseToken).balance - beforeWETHBalance, inputAmount, "WETH_BALANCE");
        assertEq(IERC20(baseToken).balanceOf(USER), beforeUserBaseAmount, "USER_BALANCE");
    }

    function testCloberMarketSwapCallbackUsingNativeWhenBalanceIsBiggerThanInputAmount() public {
        uint256 beforeWETHBalance = baseToken.balance;
        uint256 beforeUserBaseAmount = IERC20(baseToken).balanceOf(USER);
        uint256 beforeRouterETHAmount = address(router).balance;
        uint256 inputAmount = 12312421;
        uint256 extra = 123;
        vm.deal(address(market1), uint256(CLAIM_BOUNTY) * 1 gwei); // to refund claim bounty
        vm.deal(address(router), inputAmount + extra);
        vm.expectCall(baseToken, inputAmount, abi.encodeCall(IWETH.deposit, ()));
        vm.prank(address(market1));
        router.cloberMarketSwapCallback{value: uint256(CLAIM_BOUNTY) * 1 gwei}(
            baseToken, // WETH
            quoteToken,
            inputAmount,
            10,
            abi.encode(USER, USE_NATIVE, 0)
        );
        assertEq(address(baseToken).balance - beforeWETHBalance, inputAmount, "WETH_BALANCE");
        assertEq(IERC20(baseToken).balanceOf(USER), beforeUserBaseAmount, "USER_BALANCE");
        assertEq(
            address(router).balance - beforeRouterETHAmount,
            uint256(CLAIM_BOUNTY) * 1 gwei + extra,
            "ROUTER_ETH_BALANCE"
        );
    }

    function testCloberMarketSwapCallbackUsingNativeWhenInputIsBiggerThanBalance() public {
        uint256 beforeWETHBalance = baseToken.balance;
        uint256 beforeUserBaseAmount = IERC20(baseToken).balanceOf(USER);
        uint256 inputAmount = 12312421;
        uint256 extra = 123;
        vm.deal(address(router), inputAmount - extra);
        vm.expectCall(baseToken, inputAmount - extra, abi.encodeCall(IWETH.deposit, ()));
        vm.prank(address(market1));
        router.cloberMarketSwapCallback(
            baseToken, // WETH
            quoteToken,
            inputAmount,
            10,
            abi.encode(USER, USE_NATIVE, 0)
        );
        assertEq(address(router).balance, 0, "ROUTER_BALANCE");
        assertEq(address(baseToken).balance - beforeWETHBalance, inputAmount - extra, "WETH_BALANCE");
        assertEq(beforeUserBaseAmount - IERC20(baseToken).balanceOf(USER), extra, "USER_BALANCE");
    }

    function testCloberMarketSwapCallbackUsingNativeWhenInputAmountIs0() public {
        // For coverage
        vm.expectCall(baseToken, 0, abi.encodeCall(IWETH.deposit, ()));
        vm.prank(address(market1));
        router.cloberMarketSwapCallback(
            baseToken, // WETH
            quoteToken,
            0,
            10,
            abi.encode(USER, USE_NATIVE, 0)
        );
    }

    function testCloberMarketSwapCallbackAccess() public {
        marketId = 12;
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        router.cloberMarketSwapCallback(quoteToken, baseToken, 10, 10, abi.encode(USER, !USE_NATIVE, 0));
    }

    function _buildLimitOrderParams(
        address market,
        uint64 rawAmount,
        uint256 baseAmount,
        bool postOnly
    ) private view returns (CloberRouter.LimitOrderParams memory) {
        CloberRouter.LimitOrderParams memory params;
        params.market = address(market);
        params.deadline = uint64(block.timestamp + 100);
        params.claimBounty = CLAIM_BOUNTY;
        params.user = USER;
        params.rawAmount = rawAmount;
        params.priceIndex = PRICE_INDEX;
        params.postOnly = postOnly;
        params.useNative = !USE_NATIVE;
        params.baseAmount = baseAmount;
        return params;
    }

    function testLimitBid(uint64 rawAmount, bool postOnly) public {
        vm.assume(rawAmount > 0 && rawAmount < type(uint64).max);
        CloberRouter.LimitOrderParams memory params = _buildLimitOrderParams(address(market1), rawAmount, 0, postOnly);
        vm.expectCall(
            address(market1),
            uint256(CLAIM_BOUNTY) * 1 gwei,
            abi.encodeCall(
                CloberOrderBook.limitOrder,
                (
                    params.user,
                    params.priceIndex,
                    params.rawAmount,
                    params.baseAmount,
                    params.postOnly ? 3 : 1,
                    abi.encode(params.user, !USE_NATIVE, 0)
                )
            )
        );
        vm.deal(address(router), 123);
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        router.limitBid{value: uint256(CLAIM_BOUNTY) * 1 gwei}(params);
        assertEq(address(router).balance, 0, "ROUTER_BALANCE");
        assertEq(USER.balance, 123, "USER_BALANCE");
    }

    function testLimitBidDeadline() public {
        CloberRouter.LimitOrderParams memory params = _buildLimitOrderParams(address(market1), 10, 0, POST_ONLY);
        params.deadline = uint64(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        router.limitBid{value: uint256(CLAIM_BOUNTY) * 1 gwei}(params);
    }

    function testLimitAsk(uint256 baseAmount, bool postOnly) public {
        baseAmount = bound(baseAmount, 1e18, 1e7 * 1e18);
        CloberRouter.LimitOrderParams memory params = _buildLimitOrderParams(address(market1), 0, baseAmount, postOnly);
        vm.expectCall(
            address(market1),
            uint256(CLAIM_BOUNTY) * 1 gwei,
            abi.encodeCall(
                CloberOrderBook.limitOrder,
                (
                    params.user,
                    params.priceIndex,
                    params.rawAmount,
                    params.baseAmount,
                    params.postOnly ? 2 : 0,
                    abi.encode(params.user, !USE_NATIVE, 0)
                )
            )
        );
        vm.deal(address(router), 123);
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        router.limitAsk{value: uint256(CLAIM_BOUNTY) * 1 gwei}(params);
        assertEq(address(router).balance, 0, "ROUTER_BALANCE");
        assertEq(USER.balance, 123, "USER_BALANCE");
    }

    function testLimitAskDeadline() public {
        CloberRouter.LimitOrderParams memory params = _buildLimitOrderParams(address(market1), 0, 1e18, POST_ONLY);
        params.deadline = uint64(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        router.limitAsk{value: uint256(CLAIM_BOUNTY) * 1 gwei}(params);
    }

    function _buildMarketOrderParams(
        address market,
        uint64 rawAmount,
        uint256 baseAmount,
        bool expendInput
    ) internal view returns (CloberRouter.MarketOrderParams memory) {
        CloberRouter.MarketOrderParams memory params;
        params.market = address(market);
        params.deadline = uint64(block.timestamp + 100);
        params.user = USER;
        params.limitPriceIndex = PRICE_INDEX;
        params.rawAmount = rawAmount;
        params.expendInput = expendInput;
        params.baseAmount = baseAmount;
        return params;
    }

    function _presetBeforeMarketOrder(
        address market,
        uint64 rawAmount,
        uint256 baseAmount,
        bool isBid
    ) internal {
        CloberRouter.LimitOrderParams memory limitParams = _buildLimitOrderParams(
            address(market),
            rawAmount,
            baseAmount,
            POST_ONLY
        );
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        if (isBid) {
            router.limitBid{value: uint256(CLAIM_BOUNTY) * 1 gwei}(limitParams);
        } else {
            router.limitAsk{value: uint256(CLAIM_BOUNTY) * 1 gwei}(limitParams);
        }
    }

    function testMarketBid(uint256 amount, bool expendInput) public {
        _presetBeforeMarketOrder(address(market1), 0, 1e7 * 1e18, ASK);

        (uint64 rawAmount, uint256 baseAmount) = expendInput
            ? (uint64(bound(amount, 1, type(uint64).max)), 0)
            : (type(uint64).max, bound(amount, 1e18, 1e6 * 1e18));
        CloberRouter.MarketOrderParams memory params = _buildMarketOrderParams(
            address(market1),
            rawAmount,
            baseAmount,
            expendInput
        );
        vm.expectCall(
            address(market1),
            abi.encodeCall(
                CloberOrderBook.marketOrder,
                (
                    params.user,
                    params.limitPriceIndex,
                    params.rawAmount,
                    params.baseAmount,
                    params.expendInput ? 3 : 1,
                    abi.encode(params.user, !USE_NATIVE, 0)
                )
            )
        );
        vm.prank(USER);
        router.marketBid(params);
    }

    function testMarketBidDeadline() public {
        _presetBeforeMarketOrder(address(market1), 0, 1e7 * 1e18, ASK);

        CloberRouter.MarketOrderParams memory params = _buildMarketOrderParams(address(market1), 1000, 0, EXPEND_INPUT);
        params.deadline = uint64(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        vm.prank(USER);
        router.marketBid(params);
    }

    function testMarketAsk(uint256 amount, bool expendInput) public {
        _presetBeforeMarketOrder(address(market1), type(uint64).max - 1, 0, BID);

        uint32 feePrecision = 1e6;
        uint32 castedTakeFee = uint32(TAKE_FEE);
        (uint64 rawAmount, uint256 baseAmount) = expendInput
            ? (0, bound(amount, 1e18, 1e6 * 1e18))
            : (
                uint64(bound(amount, 1, (type(uint64).max / feePrecision) * (feePrecision - castedTakeFee))),
                type(uint256).max
            );
        CloberRouter.MarketOrderParams memory params = _buildMarketOrderParams(
            address(market1),
            rawAmount,
            baseAmount,
            expendInput
        );
        vm.expectCall(
            address(market1),
            abi.encodeCall(
                CloberOrderBook.marketOrder,
                (
                    params.user,
                    params.limitPriceIndex,
                    params.rawAmount,
                    params.baseAmount,
                    params.expendInput ? 2 : 0,
                    abi.encode(params.user, !USE_NATIVE, 0)
                )
            )
        );
        vm.prank(USER);
        router.marketAsk(params);
    }

    function testMarketAskDeadline() public {
        _presetBeforeMarketOrder(address(market1), type(uint64).max - 1, 0, BID);

        CloberRouter.MarketOrderParams memory params = _buildMarketOrderParams(
            address(market1),
            0,
            1e6 * 1e18,
            EXPEND_INPUT
        );
        params.deadline = uint64(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        vm.prank(USER);
        router.marketAsk(params);
    }

    function _presetBeforeClaim(address market) internal returns (OrderKey memory) {
        // before claim
        CloberRouter.LimitOrderParams memory limitParams = _buildLimitOrderParams(
            address(market),
            0,
            1e7 * 1e18,
            POST_ONLY
        );
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        uint256 orderIndex = router.limitAsk{value: uint256(CLAIM_BOUNTY) * 1 gwei}(limitParams);

        CloberRouter.MarketOrderParams memory params = _buildMarketOrderParams(address(market), 1000, 0, EXPEND_INPUT);
        vm.prank(USER);
        router.marketBid(params);
        return OrderKey(false, PRICE_INDEX, orderIndex);
    }

    function testClaim() public {
        CloberRouter.ClaimOrderParams[] memory paramsList = new CloberRouter.ClaimOrderParams[](1);
        paramsList[0].market = address(market1);
        paramsList[0].orderKeys = new OrderKey[](1);
        paramsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        vm.expectCall(address(market1), abi.encodeCall(CloberOrderBook.claim, (USER, paramsList[0].orderKeys)));
        vm.prank(USER);
        router.claim(uint64(block.timestamp + 100), paramsList);
    }

    function testClaimDeadline() public {
        CloberRouter.ClaimOrderParams[] memory paramsList = new CloberRouter.ClaimOrderParams[](1);
        paramsList[0].market = address(market1);
        paramsList[0].orderKeys = new OrderKey[](1);
        paramsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        vm.prank(USER);
        router.claim(uint64(block.timestamp - 1), paramsList);
    }

    function testLimitBidAfterClaim() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        CloberRouter.LimitOrderParams memory limitOrderParams = _buildLimitOrderParams(
            address(market2),
            10,
            0,
            POST_ONLY
        );

        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        vm.startPrank(USER);

        uint256 snapshot = vm.snapshot();
        vm.expectCall(address(market1), abi.encodeCall(CloberOrderBook.claim, (USER, claimParamsList[0].orderKeys)));
        router.limitBidAfterClaim{value: uint256(CLAIM_BOUNTY) * 1 gwei}(claimParamsList, limitOrderParams);
        vm.revertTo(snapshot);
        vm.expectCall(
            address(market2),
            uint256(CLAIM_BOUNTY) * 1 gwei,
            abi.encodeCall(
                CloberOrderBook.limitOrder,
                (
                    limitOrderParams.user,
                    limitOrderParams.priceIndex,
                    limitOrderParams.rawAmount,
                    limitOrderParams.baseAmount,
                    limitOrderParams.postOnly ? 3 : 1,
                    abi.encode(limitOrderParams.user, !USE_NATIVE, 0)
                )
            )
        );
        router.limitBidAfterClaim{value: uint256(CLAIM_BOUNTY) * 1 gwei}(claimParamsList, limitOrderParams);
        vm.stopPrank();
    }

    function testLimitBidAfterClaimDeadline() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        CloberRouter.LimitOrderParams memory limitOrderParams = _buildLimitOrderParams(
            address(market2),
            10,
            0,
            POST_ONLY
        );
        limitOrderParams.deadline = uint64(block.timestamp - 1);

        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        vm.prank(USER);
        router.limitBidAfterClaim{value: uint256(CLAIM_BOUNTY) * 1 gwei}(claimParamsList, limitOrderParams);
    }

    function testLimitAskAfterClaim() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        CloberRouter.LimitOrderParams memory limitOrderParams = _buildLimitOrderParams(
            address(market2),
            0,
            10 * 1e18,
            POST_ONLY
        );

        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        vm.startPrank(USER);

        uint256 snapshot = vm.snapshot();
        vm.expectCall(address(market1), abi.encodeCall(CloberOrderBook.claim, (USER, claimParamsList[0].orderKeys)));
        router.limitAskAfterClaim{value: uint256(CLAIM_BOUNTY) * 1 gwei}(claimParamsList, limitOrderParams);
        vm.revertTo(snapshot);
        vm.expectCall(
            address(market2),
            uint256(CLAIM_BOUNTY) * 1 gwei,
            abi.encodeCall(
                CloberOrderBook.limitOrder,
                (
                    limitOrderParams.user,
                    limitOrderParams.priceIndex,
                    limitOrderParams.rawAmount,
                    limitOrderParams.baseAmount,
                    limitOrderParams.postOnly ? 2 : 0,
                    abi.encode(limitOrderParams.user, !USE_NATIVE, 0)
                )
            )
        );
        router.limitAskAfterClaim{value: uint256(CLAIM_BOUNTY) * 1 gwei}(claimParamsList, limitOrderParams);
    }

    function testLimitAskAfterClaimDeadline() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        CloberRouter.LimitOrderParams memory limitOrderParams = _buildLimitOrderParams(
            address(market2),
            0,
            10 * 1e18,
            POST_ONLY
        );
        limitOrderParams.deadline = uint64(block.timestamp - 1);

        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        router.limitAskAfterClaim{value: uint256(CLAIM_BOUNTY) * 1 gwei}(claimParamsList, limitOrderParams);
    }

    function testMarketBidAfterClaim() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        _presetBeforeMarketOrder(address(market2), 0, 1e7 * 1e18, ASK);

        CloberRouter.MarketOrderParams memory marketOrderParams = _buildMarketOrderParams(
            address(market2),
            1000,
            0,
            EXPEND_INPUT
        );
        uint256 snapshot = vm.snapshot();
        vm.startPrank(USER);
        vm.expectCall(address(market1), abi.encodeCall(CloberOrderBook.claim, (USER, claimParamsList[0].orderKeys)));
        router.marketBidAfterClaim(claimParamsList, marketOrderParams);
        vm.revertTo(snapshot);
        vm.expectCall(
            address(market2),
            abi.encodeCall(
                CloberOrderBook.marketOrder,
                (
                    marketOrderParams.user,
                    marketOrderParams.limitPriceIndex,
                    marketOrderParams.rawAmount,
                    marketOrderParams.baseAmount,
                    marketOrderParams.expendInput ? 3 : 1,
                    abi.encode(marketOrderParams.user, !USE_NATIVE, 0)
                )
            )
        );
        router.marketBidAfterClaim(claimParamsList, marketOrderParams);
        vm.stopPrank();
    }

    function testMarketBidAfterClaimDeadline() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        _presetBeforeMarketOrder(address(market2), 0, 1e7 * 1e18, ASK);

        CloberRouter.MarketOrderParams memory marketOrderParams = _buildMarketOrderParams(
            address(market2),
            1000,
            0,
            EXPEND_INPUT
        );
        marketOrderParams.deadline = uint64(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        vm.prank(USER);
        router.marketBidAfterClaim(claimParamsList, marketOrderParams);
    }

    function testMarketAskAfterClaim() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        _presetBeforeMarketOrder(address(market2), type(uint64).max - 1, 0, BID);

        CloberRouter.MarketOrderParams memory marketOrderParams = _buildMarketOrderParams(
            address(market2),
            0,
            1e6 * 1e18,
            EXPEND_INPUT
        );
        uint256 snapshot = vm.snapshot();
        vm.startPrank(USER);
        vm.expectCall(address(market1), abi.encodeCall(CloberOrderBook.claim, (USER, claimParamsList[0].orderKeys)));
        router.marketAskAfterClaim(claimParamsList, marketOrderParams);
        vm.revertTo(snapshot);
        vm.expectCall(
            address(market2),
            abi.encodeCall(
                CloberOrderBook.marketOrder,
                (
                    marketOrderParams.user,
                    marketOrderParams.limitPriceIndex,
                    marketOrderParams.rawAmount,
                    marketOrderParams.baseAmount,
                    marketOrderParams.expendInput ? 2 : 0,
                    abi.encode(marketOrderParams.user, !USE_NATIVE, 0)
                )
            )
        );
        router.marketAskAfterClaim(claimParamsList, marketOrderParams);
        vm.stopPrank();
    }

    function testMarketAskAfterClaimDeadline() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        _presetBeforeMarketOrder(address(market2), type(uint64).max - 1, 0, BID);

        CloberRouter.MarketOrderParams memory marketOrderParams = _buildMarketOrderParams(
            address(market2),
            0,
            1e6 * 1e18,
            EXPEND_INPUT
        );
        vm.prank(USER);
        marketOrderParams.deadline = uint64(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DEADLINE));
        router.marketAskAfterClaim(claimParamsList, marketOrderParams);
    }

    function testUnregisteredMarketAccessDenial() public {
        MarketRouter newRouter = _deployNewRouter();

        CloberRouter.LimitOrderParams memory params = _buildLimitOrderParams(address(market1), 10, 0, POST_ONLY);
        params.deadline = uint64(block.timestamp + 100);
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        newRouter.limitBid{value: uint256(CLAIM_BOUNTY) * 1 gwei}(params);
    }

    function testMarketRegistration() public {
        MarketRouter newRouter = _deployNewRouter();
        address[] memory markets = new address[](1);
        markets[0] = address(market1);
        newRouter.registerMarkets(markets);
        assertEq(newRouter.isRegisteredMarket(address(market1)), true);

        CloberRouter.LimitOrderParams memory params = _buildLimitOrderParams(address(market1), 10, 0, POST_ONLY);
        params.deadline = uint64(block.timestamp + 100);
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        newRouter.limitBid{value: uint256(CLAIM_BOUNTY) * 1 gwei}(params);

        newRouter.unregisterMarkets(markets);
        assertEq(newRouter.isRegisteredMarket(address(market1)), false);

        params = _buildLimitOrderParams(address(market1), 10, 0, POST_ONLY);
        params.deadline = uint64(block.timestamp + 100);
        vm.prank(USER);
        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        newRouter.limitBid{value: uint256(CLAIM_BOUNTY) * 1 gwei}(params);
    }

    function testRegistrationPermission() public {
        address[] memory markets = new address[](1);
        markets[0] = address(market1);

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        router.registerMarkets(markets);

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        router.unregisterMarkets(markets);
    }

    function testBatchLimitOrder() public {
        CloberRouter.ClaimOrderParams[] memory claimParamsList = new CloberRouter.ClaimOrderParams[](1);
        claimParamsList[0].market = address(market1);
        claimParamsList[0].orderKeys = new OrderKey[](1);
        claimParamsList[0].orderKeys[0] = _presetBeforeClaim(address(market1));

        CloberRouter.LimitOrderParams memory bidLimitOrderParams = _buildLimitOrderParams(
            address(market2),
            10,
            0,
            POST_ONLY
        );
        bidLimitOrderParams.priceIndex--;
        CloberRouter.LimitOrderParams memory askLimitOrderParams = _buildLimitOrderParams(
            address(market2),
            0,
            10 * 1e18,
            POST_ONLY
        );

        CloberRouter.GeneralLimitOrderParams[] memory limitOrderParamsList = new CloberRouter.GeneralLimitOrderParams[](
            2
        );
        limitOrderParamsList[0].isBid = true;
        limitOrderParamsList[0].params = bidLimitOrderParams;
        limitOrderParamsList[1].isBid = false;
        limitOrderParamsList[1].params = askLimitOrderParams;

        vm.deal(USER, uint256(CLAIM_BOUNTY) * 1 gwei * 10);
        vm.startPrank(USER);

        uint256 snapshot = vm.snapshot();
        vm.expectCall(address(market1), abi.encodeCall(CloberOrderBook.claim, (USER, claimParamsList[0].orderKeys)));
        router.limitOrder{value: uint256(CLAIM_BOUNTY) * 1 gwei * 2}(limitOrderParamsList, claimParamsList);
        vm.revertTo(snapshot);
        vm.expectCall(
            address(market2),
            uint256(CLAIM_BOUNTY) * 1 gwei,
            abi.encodeCall(
                CloberOrderBook.limitOrder,
                (
                    bidLimitOrderParams.user,
                    bidLimitOrderParams.priceIndex,
                    bidLimitOrderParams.rawAmount,
                    bidLimitOrderParams.baseAmount,
                    bidLimitOrderParams.postOnly ? 3 : 1,
                    abi.encode(bidLimitOrderParams.user, !USE_NATIVE, uint256(CLAIM_BOUNTY) * 1 gwei)
                )
            )
        );
        router.limitOrder{value: uint256(CLAIM_BOUNTY) * 1 gwei * 2}(limitOrderParamsList, claimParamsList);
        vm.revertTo(snapshot);
        vm.expectCall(
            address(market2),
            uint256(CLAIM_BOUNTY) * 1 gwei,
            abi.encodeCall(
                CloberOrderBook.limitOrder,
                (
                    askLimitOrderParams.user,
                    askLimitOrderParams.priceIndex,
                    askLimitOrderParams.rawAmount,
                    askLimitOrderParams.baseAmount,
                    askLimitOrderParams.postOnly ? 2 : 0,
                    abi.encode(askLimitOrderParams.user, !USE_NATIVE, 0)
                )
            )
        );
        router.limitOrder{value: uint256(CLAIM_BOUNTY) * 1 gwei * 2}(limitOrderParamsList, claimParamsList);
        vm.stopPrank();
    }
}
