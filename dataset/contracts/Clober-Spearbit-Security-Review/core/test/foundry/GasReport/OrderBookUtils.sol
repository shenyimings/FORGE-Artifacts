// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@clober/library/contracts/Create1.sol";
import "../../../contracts/MarketFactory.sol";
import "../../../contracts/MarketRouter.sol";
import "../../../contracts/mocks/MockERC20.sol";
import "../../../contracts/mocks/MockQuoteToken.sol";
import "../../../contracts/mocks/MockBaseToken.sol";
import "../../../contracts/mocks/report/GasReporter.sol";
import "../../../contracts/MarketDeployer.sol";
import "./GasReportUtils.sol";
import "../../../contracts/PriceBookDeployer.sol";
import "../../../contracts/OrderNFTDeployer.sol";

contract OrderBookUtils is Test {
    uint24 public constant TAKE_FEE = 1000;
    int24 public constant MAKE_FEE = 600;
    uint24 public constant DAO_FEE = 150000; // 15%
    uint256 public INIT_AMOUNT = 10**18;
    uint256 public constant FEE_PRECISION = 1000000; // 1 = 0.0001%
    uint32 public constant CLAIM_BOUNTY = 100; // in gwei unit
    bool public constant BID = true;
    bool public constant ASK = false;
    bool public constant POST_ONLY = true;
    bool public constant EXPEND_INPUT = true;
    bool public constant EXPEND_OUTPUT = false;
    uint128 public constant A = 10**10;
    uint128 public constant R = 1001 * 10**15;

    MarketFactory factory;
    OrderBook public market;
    OrderNFT public orderToken;
    GasReporter public gasReporter;
    address public quoteToken;
    address public baseToken;
    OrderCanceler orderCanceler;
    MarketRouter public router;
    GeometricPriceBook public volatilePriceBook;

    function createMarket() public {
        address factoryOwner = address(this);
        uint64 nonce = vm.getNonce(address(this));
        quoteToken = address(new MockQuoteToken());
        baseToken = address(new MockBaseToken());
        orderCanceler = new OrderCanceler();
        address[] memory initialQuoteTokenRegistrations = new address[](1);
        initialQuoteTokenRegistrations[0] = quoteToken;
        factory = new MarketFactory(
            Create1.computeAddress(factoryOwner, nonce + 4),
            Create1.computeAddress(factoryOwner, nonce + 5),
            Create1.computeAddress(factoryOwner, nonce + 6),
            factoryOwner, // initialDaoTreasury
            address(orderCanceler), // canceler_
            initialQuoteTokenRegistrations
        );
        new MarketDeployer(address(factory));
        new PriceBookDeployer(address(factory));
        new OrderNFTDeployer(address(factory), address(orderCanceler));

        market = OrderBook(
            factory.createVolatileMarket(
                factoryOwner, // marketHost
                quoteToken,
                baseToken,
                GasReportUtils.QUOTE_UNIT,
                MAKE_FEE,
                TAKE_FEE,
                A,
                R
            )
        );
        orderToken = OrderNFT(market.orderToken());
        router = new MarketRouter(address(factory));
        gasReporter = new GasReporter(address(router), address(orderCanceler), address(market), address(factory));
    }

    function mintToken(address user) public {
        uint256 amount = INIT_AMOUNT * 10**(MockERC20(quoteToken).decimals());
        MockERC20(quoteToken).mint(user, amount);
        amount = INIT_AMOUNT * 10**(MockERC20(baseToken).decimals());
        MockERC20(baseToken).mint(user, amount);
        vm.deal(user, INIT_AMOUNT * 10**18);
    }

    function approveGasReporter(address user) public {
        vm.prank(user);
        orderToken.setApprovalForAll(address(gasReporter), true);
    }

    function approveRouter() public {
        vm.startPrank(address(gasReporter));
        IERC20(quoteToken).approve(address(router), type(uint256).max);
        IERC20(baseToken).approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function limitBidOrder(
        address user,
        uint16 priceIndex,
        uint256 quoteAmount,
        function(address, uint16, uint64) external payable returns (uint256) callback
    ) public returns (uint256 orderIndex) {
        uint64 rawAmount = GasReportUtils.quoteToRaw(quoteAmount, false);
        vm.startPrank(user);
        IERC20(quoteToken).transfer(address(gasReporter), GasReportUtils.rawToQuote(rawAmount));
        orderIndex = callback(user, priceIndex, rawAmount);
        vm.stopPrank();
    }

    function limitAskOrder(
        address user,
        uint16 priceIndex,
        uint256 baseAmount,
        function(address, uint16, uint256) external payable returns (uint256) callback
    ) public returns (uint256 orderIndex) {
        vm.startPrank(user);
        IERC20(baseToken).transfer(address(gasReporter), baseAmount);
        orderIndex = callback(user, priceIndex, baseAmount);
        vm.stopPrank();
    }

    function marketBidOrder(
        address user,
        uint256 quoteAmount,
        function(address, uint64) external payable callback
    ) public {
        uint64 rawAmount = GasReportUtils.quoteToRaw(quoteAmount, false);
        vm.startPrank(user);
        IERC20(quoteToken).transfer(address(gasReporter), GasReportUtils.rawToQuote(rawAmount));
        callback(user, rawAmount);
        vm.stopPrank();
    }

    function marketAskOrder(
        address user,
        uint256 baseAmount,
        function(address, uint256) external payable callback
    ) public {
        vm.startPrank(user);
        IERC20(baseToken).transfer(address(gasReporter), baseAmount);
        callback(user, baseAmount);
        vm.stopPrank();
    }

    function claimOrder(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex,
        function(bool, uint16, uint256) external payable callback
    ) public {
        callback(isBid, priceIndex, orderIndex);
    }

    function cancelOrder(
        address user,
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex,
        function(uint256) external payable callback
    ) public {
        vm.prank(user);
        callback(GasReportUtils.encodeId(isBid, priceIndex, orderIndex));
    }

    function getDepth(bool isBid, uint16 priceIndex) public view returns (uint64) {
        return market.getDepth(isBid, priceIndex);
    }

    function bestPriceIndex(bool isBid) public view returns (uint16) {
        return market.bestPriceIndex(isBid);
    }
}
