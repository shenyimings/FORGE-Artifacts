// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@clober/library/contracts/Create1.sol";
import "../../../contracts/MarketFactory.sol";
import "../../../contracts/mocks/MockERC20.sol";
import "../../../contracts/MarketDeployer.sol";
import "../../../contracts/PriceBookDeployer.sol";
import "../../../contracts/OrderNFTDeployer.sol";

contract MarketFactoryUnitTest is Test {
    event CreateVolatileMarket(
        address indexed market,
        address orderToken,
        address quoteToken,
        address baseToken,
        uint256 quoteUnit,
        uint256 nonce,
        int24 makerFee,
        uint24 takerFee,
        uint128 a,
        uint128 r
    );
    event CreateStableMarket(
        address indexed market,
        address orderToken,
        address quoteToken,
        address baseToken,
        uint256 quoteUnit,
        uint256 nonce,
        int24 makerFee,
        uint24 takerFee,
        uint128 a,
        uint128 d
    );
    event ChangeHost(address indexed market, address previousHost, address newHost);
    event ChangeOwner(address previousOwner, address newOwner);
    event ChangeDaoTreasury(address previousTreasury, address newTreasury);

    uint24 public constant MAX_FEE = 500000;
    int24 public constant MIN_FEE = -500000;
    uint24 private constant _VOLATILE_MIN_NET_FEE = 400; // 0.04%
    uint24 private constant _STABLE_MIN_NET_FEE = 80; // 0.008%
    uint96 constant QUOTE_UNIT = 10000;
    int24 constant MAKER_FEE = -1000;
    uint24 constant TAKER_FEE = 2000;

    MarketFactory factory;
    MarketDeployer marketDeployer;
    PriceBookDeployer priceBookDeployer;
    OrderNFTDeployer orderTokenDeployer;
    address quoteToken;
    address baseToken;
    address proxy;

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
        baseToken = address(new MockERC20("base", "BASE", 18));
        proxy = address(new TransparentUpgradeableProxy(address(factory), address(123), new bytes(0)));
        factory.registerQuoteToken(quoteToken);
    }

    function testCreateVolatileMarket() public {
        uint128 a = 10**10;
        uint128 r = 1001 * 10**15;
        uint256 currentNonce = factory.nonce();
        bytes32 salt = keccak256(abi.encode(block.chainid, currentNonce));
        address expectedOrderTokenAddress = orderTokenDeployer.computeTokenAddress(salt);
        address expectedPriceBookAddress = priceBookDeployer.computeGeometricPriceBookAddress(a, r);
        assert(factory.deployedGeometricPriceBook(a, r) == address(0));
        vm.expectCall(
            address(marketDeployer),
            abi.encodeCall(
                marketDeployer.deploy,
                (
                    expectedOrderTokenAddress,
                    quoteToken,
                    baseToken,
                    salt,
                    QUOTE_UNIT,
                    MAKER_FEE,
                    TAKER_FEE,
                    expectedPriceBookAddress
                )
            )
        );
        vm.expectEmit(false, false, false, true);
        emit CreateVolatileMarket(
            address(0),
            expectedOrderTokenAddress,
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            currentNonce,
            MAKER_FEE,
            TAKER_FEE,
            a,
            r
        );
        CloberOrderBook market = CloberOrderBook(
            factory.createVolatileMarket(address(this), quoteToken, baseToken, QUOTE_UNIT, MAKER_FEE, TAKER_FEE, a, r)
        );
        assertEq(market.quoteToken(), quoteToken, "MARKET_QUOTE_TOKEN");
        assertEq(market.baseToken(), baseToken, "MARKET_BASE_TOKEN");
        assertEq(market.quoteUnit(), QUOTE_UNIT, "MARKET_QUOTE_UNIT");
        assertEq(market.makerFee(), MAKER_FEE, "MARKET_MAKER_FEE");
        assertEq(market.takerFee(), TAKER_FEE, "MARKET_TAKER_FEE");
        assertEq(factory.nonce() - currentNonce, 1, "FACTORY_NONCE");
        assertEq(factory.getMarketHost(address(market)), address(this), "MARKET_HOST");
        CloberMarketFactory.MarketInfo memory marketInfo = factory.getMarketInfo(address(market));
        assertEq(marketInfo.host, address(this), "MARKET_INFO_HOST");
        assertEq(uint256(marketInfo.marketType), uint256(CloberMarketFactory.MarketType.VOLATILE), "MARKET_INFO_TYPE");
        assertEq(marketInfo.a, 10**10, "MARKET_INFO_A");
        assertEq(marketInfo.factor, 1001 * 10**15, "MARKET_INFO_FACTOR");
        assert(factory.deployedGeometricPriceBook(a, r) != address(0));
        assert(factory.deployedGeometricPriceBook(a, r) == priceBookDeployer.computeGeometricPriceBookAddress(a, r));
        assertEq(factory.deployedGeometricPriceBook(a, r + 1), address(0));
    }

    function testCreateVolatileMarketViaDelegateCall() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DELEGATE_CALL));
        CloberMarketFactory(proxy).createVolatileMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            MAKER_FEE,
            TAKER_FEE,
            10**10,
            1001 * 10**15
        );
    }

    function testCreateVolatileMarketWithInvalidFeeRange() public {
        // invalid makerFee
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createVolatileMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            int24(MAX_FEE + 1),
            TAKER_FEE,
            10**10,
            1001 * 10**15
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createVolatileMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            MIN_FEE - 1,
            TAKER_FEE,
            10**10,
            1001 * 10**15
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createVolatileMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            -int24(TAKER_FEE + 1),
            TAKER_FEE,
            10**10,
            1001 * 10**15
        );
        // invalid takerFee
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createVolatileMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            MAKER_FEE,
            MAX_FEE + 1,
            10**10,
            1001 * 10**15
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createVolatileMarket(address(0x123), quoteToken, baseToken, QUOTE_UNIT, -20, 19, 10**10, 1001 * 10**15);
    }

    function testCreateVolatileMarketTooLessNetFee() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createVolatileMarket(
            address(0x123),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            -int24(_VOLATILE_MIN_NET_FEE),
            _VOLATILE_MIN_NET_FEE,
            10**10,
            1001 * 10**15
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createVolatileMarket(
            address(0x123),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            int24(_VOLATILE_MIN_NET_FEE - 1),
            0,
            10**10,
            1001 * 10**15
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createVolatileMarket(
            address(0x123),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            0,
            _VOLATILE_MIN_NET_FEE - 1,
            10**10,
            1001 * 10**15
        );
    }

    function testCreateVolatileMarketTooLessNetFeeByFactoryOwner() public {
        uint256 currentNonce = factory.nonce();
        bytes32 salt = keccak256(abi.encode(block.chainid, currentNonce));
        address expectedOrderTokenAddress = orderTokenDeployer.computeTokenAddress(salt);
        address expectedPriceBookAddress = priceBookDeployer.computeGeometricPriceBookAddress(10**10, 1001 * 10**15);
        vm.expectCall(
            address(marketDeployer),
            abi.encodeCall(
                marketDeployer.deploy,
                (expectedOrderTokenAddress, quoteToken, baseToken, salt, QUOTE_UNIT, 10, 10, expectedPriceBookAddress)
            )
        );
        CloberOrderBook market = CloberOrderBook(
            factory.createVolatileMarket(
                address(this),
                quoteToken,
                baseToken,
                QUOTE_UNIT,
                10,
                10,
                10**10,
                1001 * 10**15
            )
        );
        assertEq(market.quoteToken(), quoteToken, "MARKET_QUOTE_TOKEN");
        assertEq(market.baseToken(), baseToken, "MARKET_BASE_TOKEN");
        assertEq(market.quoteUnit(), QUOTE_UNIT, "MARKET_QUOTE_UNIT");
        assertEq(market.makerFee(), 10, "MARKET_MAKER_FEE");
        assertEq(market.takerFee(), 10, "MARKET_TAKER_FEE");
        assertEq(factory.nonce() - currentNonce, 1, "FACTORY_NONCE");
        assertEq(factory.getMarketHost(address(market)), address(this), "MARKET_HOST");
        CloberMarketFactory.MarketInfo memory marketInfo = factory.getMarketInfo(address(market));
        assertEq(marketInfo.host, address(this), "MARKET_INFO_HOST");
        assertEq(uint256(marketInfo.marketType), uint256(CloberMarketFactory.MarketType.VOLATILE), "MARKET_INFO_TYPE");
        assertEq(marketInfo.a, 10**10, "MARKET_INFO_A");
        assertEq(marketInfo.factor, 1001 * 10**15, "MARKET_INFO_FACTOR");
    }

    function testCreateVolatileMarketWhenHostIsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        factory.createVolatileMarket(
            address(0),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            MAKER_FEE,
            TAKER_FEE,
            10**10,
            1001 * 10**15
        );
    }

    function testCreateVolatileMarketWithUnregisteredQuoteToken() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_QUOTE_TOKEN));
        factory.createVolatileMarket(
            address(this),
            address(0x123),
            baseToken,
            QUOTE_UNIT,
            MAKER_FEE,
            TAKER_FEE,
            10**10,
            1001 * 10**15
        );
    }

    function testCreateStableMarket() public {
        uint128 a = 10**14;
        uint128 d = 10**14;
        uint256 currentNonce = factory.nonce();
        bytes32 salt = keccak256(abi.encode(block.chainid, currentNonce));
        address expectedOrderTokenAddress = orderTokenDeployer.computeTokenAddress(salt);
        address expectedPriceBookAddress = priceBookDeployer.computeArithmeticPriceBookAddress(a, d);
        assert(factory.deployedGeometricPriceBook(a, d) == address(0));
        vm.expectCall(
            address(marketDeployer),
            abi.encodeCall(
                marketDeployer.deploy,
                (
                    expectedOrderTokenAddress,
                    quoteToken,
                    baseToken,
                    salt,
                    QUOTE_UNIT,
                    MAKER_FEE,
                    TAKER_FEE,
                    expectedPriceBookAddress
                )
            )
        );
        vm.expectEmit(false, false, false, true);
        emit CreateStableMarket(
            address(0),
            expectedOrderTokenAddress,
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            currentNonce,
            MAKER_FEE,
            TAKER_FEE,
            a,
            d
        );
        CloberOrderBook market = CloberOrderBook(
            factory.createStableMarket(address(this), quoteToken, baseToken, QUOTE_UNIT, MAKER_FEE, TAKER_FEE, a, d)
        );
        assertEq(market.quoteToken(), quoteToken, "MARKET_QUOTE_TOKEN");
        assertEq(market.baseToken(), baseToken, "MARKET_BASE_TOKEN");
        assertEq(market.quoteUnit(), QUOTE_UNIT, "MARKET_QUOTE_UNIT");
        assertEq(market.makerFee(), MAKER_FEE, "MARKET_MAKER_FEE");
        assertEq(market.takerFee(), TAKER_FEE, "MARKET_TAKER_FEE");
        assertEq(factory.nonce() - currentNonce, 1, "FACTORY_NONCE");
        assertEq(factory.getMarketHost(address(market)), address(this), "MARKET_HOST");
        CloberMarketFactory.MarketInfo memory marketInfo = factory.getMarketInfo(address(market));
        assertEq(marketInfo.host, address(this), "MARKET_INFO_HOST");
        assertEq(uint256(marketInfo.marketType), uint256(CloberMarketFactory.MarketType.STABLE), "MARKET_INFO_TYPE");
        assertEq(marketInfo.a, 10**14, "MARKET_INFO_A");
        assertEq(marketInfo.factor, 10**14, "MARKET_INFO_FACTOR");
        assert(factory.deployedArithmeticPriceBook(a, d) != address(0));
        assert(factory.deployedArithmeticPriceBook(a, d) == priceBookDeployer.computeArithmeticPriceBookAddress(a, d));
        assertEq(factory.deployedArithmeticPriceBook(a, d + 1), address(0));
    }

    function testCreateStableMarketViaDelegateCall() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.DELEGATE_CALL));
        CloberMarketFactory(proxy).createStableMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            MAKER_FEE,
            TAKER_FEE,
            10**14,
            10**14
        );
    }

    function testCreateStableMarketWithInvalidFeeRange() public {
        // invalid makerFee
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createStableMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            int24(MAX_FEE + 1),
            TAKER_FEE,
            10**14,
            10**14
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createStableMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            MIN_FEE - 1,
            TAKER_FEE,
            10**14,
            10**14
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createStableMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            -int24(TAKER_FEE + 1),
            TAKER_FEE,
            10**14,
            10**14
        );
        // invalid takerFee
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createStableMarket(
            address(this),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            MAKER_FEE,
            MAX_FEE + 1,
            10**14,
            10**14
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createStableMarket(address(0x123), quoteToken, baseToken, QUOTE_UNIT, -20, 19, 10**14, 10**14);
    }

    function testCreateStableMarketTooLessNetFee() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createStableMarket(
            address(0x123),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            -int24(_STABLE_MIN_NET_FEE),
            _STABLE_MIN_NET_FEE,
            10**14,
            10**14
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createStableMarket(
            address(0x123),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            int24(_STABLE_MIN_NET_FEE - 1),
            0,
            10**14,
            10**14
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_FEE));
        factory.createStableMarket(
            address(0x123),
            quoteToken,
            baseToken,
            QUOTE_UNIT,
            0,
            _STABLE_MIN_NET_FEE - 1,
            10**14,
            10**14
        );
    }

    function testCreateStableMarketTooLessNetFeeByFactoryOwner() public {
        uint256 currentNonce = factory.nonce();
        bytes32 salt = keccak256(abi.encode(block.chainid, currentNonce));
        address expectedOrderTokenAddress = orderTokenDeployer.computeTokenAddress(salt);
        address expectedPriceBookAddress = priceBookDeployer.computeArithmeticPriceBookAddress(10**14, 10**14);
        vm.expectCall(
            address(marketDeployer),
            abi.encodeCall(
                marketDeployer.deploy,
                (expectedOrderTokenAddress, quoteToken, baseToken, salt, QUOTE_UNIT, 10, 10, expectedPriceBookAddress)
            )
        );
        CloberOrderBook market = CloberOrderBook(
            factory.createStableMarket(address(this), quoteToken, baseToken, QUOTE_UNIT, 10, 10, 10**14, 10**14)
        );
        assertEq(market.quoteToken(), quoteToken, "MARKET_QUOTE_TOKEN");
        assertEq(market.baseToken(), baseToken, "MARKET_BASE_TOKEN");
        assertEq(market.quoteUnit(), QUOTE_UNIT, "MARKET_QUOTE_UNIT");
        assertEq(market.makerFee(), 10, "MARKET_MAKER_FEE");
        assertEq(market.takerFee(), 10, "MARKET_TAKER_FEE");
        assertEq(factory.nonce() - currentNonce, 1, "FACTORY_NONCE");
        assertEq(factory.getMarketHost(address(market)), address(this), "MARKET_HOST");
        CloberMarketFactory.MarketInfo memory marketInfo = factory.getMarketInfo(address(market));
        assertEq(marketInfo.host, address(this), "MARKET_INFO_HOST");
        assertEq(uint256(marketInfo.marketType), uint256(CloberMarketFactory.MarketType.STABLE), "MARKET_INFO_TYPE");
        assertEq(marketInfo.a, 10**14, "MARKET_INFO_A");
        assertEq(marketInfo.factor, 10**14, "MARKET_INFO_FACTOR");
    }

    function testCreateStableMarketWhenHostIsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        factory.createStableMarket(address(0), quoteToken, baseToken, QUOTE_UNIT, MAKER_FEE, TAKER_FEE, 10**14, 10**14);
    }

    function testCreateStableMarketWithUnregisteredQuoteToken() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_QUOTE_TOKEN));
        factory.createStableMarket(
            address(0),
            address(0x123),
            baseToken,
            QUOTE_UNIT,
            MAKER_FEE,
            TAKER_FEE,
            10**14,
            10**14
        );
    }

    function testChangeDaoTreasury() public {
        assertEq(factory.daoTreasury(), address(this));
        address newAddress = address(2);
        vm.expectEmit(true, true, true, true);
        emit ChangeDaoTreasury(address(this), address(2));
        factory.changeDaoTreasury(newAddress);
        assertEq(factory.daoTreasury(), newAddress);
    }

    function testChangeDaoTreasuryAccess() public {
        address newAddress = address(2);
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        factory.changeDaoTreasury(newAddress);
    }

    function testPrepareChangeOwner() public {
        assertEq(factory.owner(), address(this), "BEFORE_NEW_OWNER");
        assertEq(factory.futureOwner(), address(0), "AFTER_FUTURE_OWNER");
        address newAddress = address(1);
        factory.prepareChangeOwner(newAddress);
        assertEq(factory.owner(), address(this), "NEW_OWNER");
        assertEq(factory.futureOwner(), newAddress, "FUTURE_OWNER");
    }

    function testPrepareChangeOwnerAccess() public {
        address newAddress = address(2);
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        factory.prepareChangeOwner(newAddress);
    }

    function testExecuteChangeOwner() public {
        address newAddress = address(1);
        factory.prepareChangeOwner(newAddress);

        vm.expectEmit(true, true, true, true);
        emit ChangeOwner(address(this), address(1));
        vm.prank(newAddress);
        factory.executeChangeOwner();
        assertEq(factory.owner(), newAddress, "NEW_OWNER");
        assertEq(factory.futureOwner(), address(0), "FUTURE_OWNER");
    }

    function testExecuteChangeOwnerAccess() public {
        address newAddress = address(1);
        factory.prepareChangeOwner(newAddress);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        factory.executeChangeOwner();
    }

    function testGetMarketHostWithZeroAddress() public {
        assertEq(factory.getMarketHost(address(0)), address(0));
    }

    function _createMarket() internal returns (address) {
        return
            factory.createStableMarket(
                address(this),
                quoteToken,
                baseToken,
                QUOTE_UNIT,
                MAKER_FEE,
                TAKER_FEE,
                10**14,
                10**14
            );
    }

    function testPrepareHandOverHost() public {
        address market = _createMarket();
        address newHost = address(123);
        factory.prepareHandOverHost(market, newHost);
        assertEq(factory.getMarketHost(market), address(this), "MARKET_HOST");
        assertEq(factory.getMarketInfo(market).futureHost, newHost, "MARKET_FUTURE_HOST");
    }

    function testPrepareHandOverHostAccess() public {
        address market = _createMarket();
        vm.prank(address(0x111));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        factory.prepareHandOverHost(market, address(0x312));
    }

    function testExecuteHandOverHost() public {
        address market = _createMarket();
        address newHost = address(123);
        factory.prepareHandOverHost(market, newHost);

        vm.expectEmit(true, true, true, true);
        emit ChangeHost(market, address(this), newHost);
        vm.prank(newHost);
        factory.executeHandOverHost(market);
        assertEq(factory.getMarketHost(market), newHost, "MARKET_HOST");
        assertEq(factory.getMarketInfo(market).futureHost, address(0), "MARKET_FUTURE_HOST");
    }

    function testExecuteHandOverHostAccess() public {
        address market = _createMarket();
        address newHost = address(123);
        factory.prepareHandOverHost(market, newHost);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        factory.executeHandOverHost(market);
    }

    function testRegisterQuoteToken() public {
        assertTrue(!factory.registeredQuoteTokens(address(0x123)));
        factory.registerQuoteToken(address(0x123));
        assertTrue(factory.registeredQuoteTokens(address(0x123)));
    }

    function testRegisterQuoteTokenAccess() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(address(0x123));
        factory.registerQuoteToken(address(0x123));
    }

    function testUnregisterQuoteToken() public {
        factory.registerQuoteToken(address(0x123));

        assertTrue(factory.registeredQuoteTokens(address(0x123)));
        factory.unregisterQuoteToken(address(0x123));
        assertTrue(!factory.registeredQuoteTokens(address(0x123)));
    }

    function testUnregisterQuoteTokenAccess() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(address(0x123));
        factory.unregisterQuoteToken(address(0x123));
    }

    function testComputeTokenAddressIndependentFromChainId() public {
        uint256 nonce = 240;
        uint256 beforeChanId = block.chainid;
        bytes32 salt = keccak256(abi.encode(block.chainid, nonce));
        address beforeAddress = orderTokenDeployer.computeTokenAddress(salt);
        vm.chainId(beforeChanId + 1);
        assertEq(block.chainid, beforeChanId + 1, "CHAIN_ID");
        assertEq(orderTokenDeployer.computeTokenAddress(salt), beforeAddress, "ADDRESS");
    }

    function testFormatOrderTokenName() public {
        uint256 nonce = 10;
        assertEq(factory.formatOrderTokenName(quoteToken, baseToken, nonce), "Clober Order: BASE/QUOTE(10)", "NAME");
    }

    function testFormatOrderTokenSymbol() public {
        uint256 nonce = 10;
        assertEq(factory.formatOrderTokenSymbol(quoteToken, baseToken, nonce), "CLOB-BASE/QUOTE(10)", "SYMBOL");
    }

    function testZeroQuoteUnit() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        factory.createStableMarket(address(this), quoteToken, baseToken, 0, MAKER_FEE, TAKER_FEE, 10**14, 10**14);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        factory.createVolatileMarket(
            address(this),
            quoteToken,
            baseToken,
            0,
            MAKER_FEE,
            TAKER_FEE,
            10**10,
            1001 * 10**15
        );
    }

    function testDeployArithmeticPriceBookAccess() public {
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        priceBookDeployer.deployArithmeticPriceBook(10**14, 10**14);
    }

    function testDeployGeometricPriceBookAccess() public {
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        priceBookDeployer.deployGeometricPriceBook(10**10, 1001 * 10**15);
    }

    function testDeployOrderTokenAccess() public {
        uint256 currentNonce = factory.nonce();
        bytes32 salt = keccak256(abi.encode(block.chainid, currentNonce));
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderTokenDeployer.deploy(salt);
    }
}
