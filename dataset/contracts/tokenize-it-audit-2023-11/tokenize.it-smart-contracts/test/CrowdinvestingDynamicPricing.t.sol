// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/factories/FeeSettingsCloneFactory.sol";
import "../contracts/factories/CrowdinvestingCloneFactory.sol";
import "../contracts/factories/PriceLinearCloneFactory.sol";
import "./resources/FakePaymentToken.sol";
import "./resources/MaliciousPaymentToken.sol";
import "./resources/CloneCreators.sol";

/// fixture that always returns max price
contract MaxPriceOracle is IPriceDynamic {
    uint256 nonsensePrice; // this only exists to silence compiler warnings

    constructor() {
        nonsensePrice = 7;
    }

    // solhint-disable-next-line
    function getPrice(uint256 basePrice) external view returns (uint256) {
        // this always returns 0
        basePrice = nonsensePrice > basePrice ? nonsensePrice : basePrice;
        return basePrice < type(uint256).max ? type(uint256).max : basePrice;
    }
}

/// fixture that always returns max price
contract MinPriceOracle is IPriceDynamic {
    uint256 nonsensePrice; // this only exists to silence compiler warnings

    constructor() {
        nonsensePrice = 7;
    }

    // solhint-disable-next-line
    function getPrice(uint256 basePrice) external view returns (uint256) {
        // this always returns type(uint256).max
        basePrice = nonsensePrice > basePrice ? nonsensePrice : basePrice;
        return basePrice > 0 ? 0 : basePrice;
    }
}

contract CrowdinvestingTest is Test {
    event CurrencyReceiverChanged(address indexed);
    event MinAmountPerBuyerChanged(uint256);
    event MaxAmountPerBuyerChanged(uint256);
    event TokenPriceAndCurrencyChanged(uint256, IERC20 indexed);
    event MaxAmountOfTokenToBeSoldChanged(uint256);
    event TokensBought(address indexed buyer, uint256 tokenAmount, uint256 currencyAmount);

    CrowdinvestingCloneFactory factory;
    Crowdinvesting crowdinvesting;
    AllowList list;
    IFeeSettingsV2 feeSettings;

    TokenProxyFactory tokenCloneFactory;
    Token token;
    FakePaymentToken paymentToken;
    PriceLinearCloneFactory priceLinearCloneFactory;

    address public constant companyAdmin = address(1);
    address public constant buyer = address(2);
    address public constant mintAllower = address(3);
    address public constant minter = address(4);
    address public constant owner = address(5);
    address public constant receiver = address(6);
    address public constant paymentTokenProvider = address(7);
    address public constant trustedForwarder = address(8);
    address public constant platformAdmin = address(9);

    uint8 public constant paymentTokenDecimals = 6;
    uint256 public constant paymentTokenAmount = 1000 * 10 ** paymentTokenDecimals;

    uint256 public constant price = 7 * 10 ** paymentTokenDecimals; // 7 payment tokens per token

    uint256 public constant maxAmountOfTokenToBeSold = 20 * 10 ** 18; // 20 token
    uint256 public constant maxAmountPerBuyer = maxAmountOfTokenToBeSold / 2; // 10 token
    uint256 public constant minAmountPerBuyer = maxAmountOfTokenToBeSold / 200; // 0.1 token

    function setUp() public {
        // set up currency
        vm.prank(paymentTokenProvider);
        paymentToken = new FakePaymentToken(paymentTokenAmount, paymentTokenDecimals); // 1000 tokens with 6 decimals
        // transfer currency to buyer
        vm.prank(paymentTokenProvider);
        paymentToken.transfer(buyer, paymentTokenAmount);
        assertTrue(paymentToken.balanceOf(buyer) == paymentTokenAmount);

        // set up platform
        vm.startPrank(platformAdmin);
        list = createAllowList(trustedForwarder, owner);
        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 100);
        FeeSettings feeLogic = new FeeSettings(trustedForwarder);
        FeeSettingsCloneFactory feeSettingsCloneFactory = new FeeSettingsCloneFactory(address(feeLogic));
        feeSettings = IFeeSettingsV2(
            feeSettingsCloneFactory.createFeeSettingsClone(
                0,
                trustedForwarder,
                platformAdmin,
                fees,
                platformAdmin,
                platformAdmin,
                platformAdmin
            )
        );

        // create token
        address tokenLogicContract = address(new Token(trustedForwarder));
        tokenCloneFactory = new TokenProxyFactory(tokenLogicContract);
        token = Token(
            tokenCloneFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                companyAdmin,
                list,
                0x0,
                "TESTTOKEN",
                "TEST"
            )
        );

        // create fundraising
        factory = new CrowdinvestingCloneFactory(address(new Crowdinvesting(trustedForwarder)));
        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            companyAdmin,
            payable(receiver),
            minAmountPerBuyer,
            maxAmountPerBuyer,
            price,
            price,
            price,
            maxAmountOfTokenToBeSold,
            paymentToken,
            token,
            0,
            address(0)
        );
        crowdinvesting = Crowdinvesting(factory.createCrowdinvestingClone(0, trustedForwarder, arguments));

        vm.stopPrank();

        // allow crowdinvesting contract to mint
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(companyAdmin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(address(crowdinvesting), maxAmountOfTokenToBeSold);

        // give crowdinvesting contract allowance
        vm.prank(buyer);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        // set up price oracle factory
        PriceLinear priceLinearLogicContract = new PriceLinear(trustedForwarder);
        priceLinearCloneFactory = new PriceLinearCloneFactory(address(priceLinearLogicContract));
    }

    function testDynamicPricingLinearTime(uint64 timeShift) public {
        vm.assume(timeShift > 1 days);
        vm.warp(0);
        uint256 startTime = 1 days + 1;

        vm.startPrank(companyAdmin);

        // set up price oracle to increase the price by 1 payment token per second
        PriceLinear priceOracle = PriceLinear(
            priceLinearCloneFactory.createPriceLinearClone(
                0,
                trustedForwarder,
                companyAdmin,
                1e6,
                1,
                uint64(startTime),
                1,
                false,
                true
            )
        );

        // configure crowdinvesting to use oracle
        crowdinvesting.pause();
        crowdinvesting.activateDynamicPricing(
            IPriceDynamic(priceOracle),
            crowdinvesting.priceBase(),
            crowdinvesting.priceBase() * 2
        );
        vm.warp(startTime);
        crowdinvesting.unpause();

        vm.stopPrank();

        // check time and price
        console.log("Timestamp matches tomorrow: %s", block.timestamp == startTime);
        uint256 currentPrice = crowdinvesting.getPrice();
        console.log("Price: %s", currentPrice);
        assertTrue(currentPrice == price, "Price should be equal to base price before start time");

        // check price 1 second later
        vm.warp(startTime + 1);
        currentPrice = crowdinvesting.getPrice();
        console.log("Price: %s", currentPrice);
        assertTrue(currentPrice == price + 1e6, "Price should be equal to base price + 1 payment token");

        // buy now and make sure this price was used
        assertEq(token.balanceOf(buyer), 0, "Buyer should have 0 tokens before");
        uint256 buyerPaymentTokenBalanceBefore = paymentToken.balanceOf(buyer);
        vm.prank(buyer);
        crowdinvesting.buy(1e18, buyer);
        assertTrue(token.balanceOf(buyer) == 1e18, "Buyer should have 1 token");
        assertEq(
            paymentToken.balanceOf(buyer),
            buyerPaymentTokenBalanceBefore - currentPrice,
            "Buyer should have paid currentPrice"
        );

        // check price 4 seconds later
        vm.warp(startTime + 4);
        currentPrice = crowdinvesting.getPrice();
        console.log("Price: %s", currentPrice);
        assertTrue(currentPrice == price + 4 * 1e6, "Price should be equal to base price + 4 payment token");

        // check price much later
        vm.warp(startTime + 1 days);
        currentPrice = crowdinvesting.getPrice();
        console.log("Price: %s", currentPrice);
        assertTrue(currentPrice == price * 2, "Price should be equal to max price");

        // check price timeShift later
        vm.warp(startTime + timeShift);
        currentPrice = crowdinvesting.getPrice();
        console.log("Price: %s", currentPrice);
        assertTrue(currentPrice == price * 2, "Price should be equal to max price after timeShift");
    }

    function testMaxPrice(uint256 maxPrice) public {
        vm.assume(maxPrice >= price);
        vm.warp(0);

        // deploy max price oracle
        MaxPriceOracle maxPriceOracle = new MaxPriceOracle();

        // configure crowdinvesting to use oracle
        vm.startPrank(companyAdmin);
        crowdinvesting.pause();
        crowdinvesting.activateDynamicPricing(IPriceDynamic(maxPriceOracle), crowdinvesting.priceBase(), maxPrice);
        vm.warp(1 days + 1);
        crowdinvesting.unpause();

        vm.stopPrank();

        // check price
        uint256 currentPrice = crowdinvesting.getPrice();
        console.log("Price: %s", currentPrice);
        assertTrue(currentPrice == maxPrice, "Price should be equal to max price");
    }

    function testMinPrice(uint256 minPrice) public {
        vm.assume(minPrice <= price);
        vm.warp(0);

        // deploy max price oracle
        MinPriceOracle maxPriceOracle = new MinPriceOracle();

        // configure crowdinvesting to use oracle
        vm.startPrank(companyAdmin);
        crowdinvesting.pause();
        crowdinvesting.activateDynamicPricing(IPriceDynamic(maxPriceOracle), minPrice, crowdinvesting.priceBase());
        vm.warp(1 days + 1);
        crowdinvesting.unpause();

        vm.stopPrank();

        // check price
        uint256 currentPrice = crowdinvesting.getPrice();
        console.log("Price: %s", currentPrice);
        assertTrue(currentPrice == minPrice, "Price should be equal to min price");
    }
}
