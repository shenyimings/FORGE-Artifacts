// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/factories/CrowdinvestingCloneFactory.sol";
import "../contracts/factories/PriceLinearCloneFactory.sol";
import "../contracts/PriceLinear.sol";
import "./resources/FakePaymentToken.sol";
import "./resources/MaliciousPaymentToken.sol";
import "./resources/CloneCreators.sol";

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

    address wrongFeeReceiver = address(5);

    TokenProxyFactory tokenCloneFactory;
    Token token;
    FakePaymentToken paymentToken;

    PriceLinear priceLinearLogicContract = new PriceLinear(trustedForwarder);
    PriceLinearCloneFactory priceLinearCloneFactory = new PriceLinearCloneFactory(address(priceLinearLogicContract));

    address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant buyer = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant minter = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant owner = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant receiver = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant paymentTokenProvider = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    uint8 public constant paymentTokenDecimals = 6;
    uint256 public constant paymentTokenAmount = 1000 * 10 ** paymentTokenDecimals;

    uint256 public constant price = 7 * 10 ** paymentTokenDecimals;
    uint256 public constant priceMin = 1 * 10 ** paymentTokenDecimals;
    uint256 public constant priceMax = 100 * 10 ** paymentTokenDecimals;

    uint256 public constant maxAmountOfTokenToBeSold = 20 * 10 ** 18; // 20 token
    uint256 public constant maxAmountPerBuyer = maxAmountOfTokenToBeSold / 2; // 10 token
    uint256 public constant minAmountPerBuyer = maxAmountOfTokenToBeSold / 200; // 0.1 token

    function setUp() public {
        list = createAllowList(trustedForwarder, owner);
        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 100);
        feeSettings = createFeeSettings(
            trustedForwarder,
            address(this),
            fees,
            wrongFeeReceiver,
            admin,
            wrongFeeReceiver
        );

        // create token
        address tokenLogicContract = address(new Token(trustedForwarder));
        tokenCloneFactory = new TokenProxyFactory(tokenLogicContract);
        token = Token(
            tokenCloneFactory.createTokenProxy(0, trustedForwarder, feeSettings, admin, list, 0x0, "TESTTOKEN", "TEST")
        );

        // set up currency
        vm.prank(paymentTokenProvider);
        paymentToken = new FakePaymentToken(paymentTokenAmount, paymentTokenDecimals); // 1000 tokens with 6 decimals
        // transfer currency to buyer
        vm.prank(paymentTokenProvider);
        paymentToken.transfer(buyer, paymentTokenAmount);
        assertTrue(paymentToken.balanceOf(buyer) == paymentTokenAmount);

        vm.prank(owner);
        factory = new CrowdinvestingCloneFactory(address(new Crowdinvesting(trustedForwarder)));

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            owner,
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

        // allow crowdinvesting contract to mint
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(address(crowdinvesting), maxAmountOfTokenToBeSold);

        // give crowdinvesting contract allowance
        vm.prank(buyer);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);
    }

    function testActivateDynamicPricingAndEnforceMaxPrice(
        uint64 priceIncreasePerDuration,
        uint64 duration,
        uint64 startDate,
        uint64 testDate
    ) public {
        vm.assume(priceIncreasePerDuration > 0);
        vm.assume(duration > 0);
        vm.assume(startDate > 1 hours + 1);
        vm.assume(testDate > 0);
        // create oracle
        vm.warp(1 hours + 1); // otherwise, price linear thinks it has to cool down
        PriceLinear priceLinear = PriceLinear(
            priceLinearCloneFactory.createPriceLinearClone(
                0,
                trustedForwarder,
                owner,
                priceIncreasePerDuration,
                duration,
                startDate,
                1,
                false,
                true
            )
        );
        // check cooldown start
        assertEq(crowdinvesting.coolDownStart(), 0, "Cooldown start not set correctly");

        // activate dynamic pricing
        vm.startPrank(owner);
        crowdinvesting.pause();
        crowdinvesting.activateDynamicPricing(priceLinear, priceMin, priceMax);
        assertEq(crowdinvesting.coolDownStart(), block.timestamp, "Cooldown start not set correctly");

        vm.warp(block.timestamp + crowdinvesting.delay() + 1);
        crowdinvesting.unpause();
        vm.stopPrank();

        // check dynamic pricing
        if (block.timestamp < startDate) {
            console.log("Start date not reached yet: ", startDate);
            console.log("Current price: ", crowdinvesting.getPrice());
            assertEq(crowdinvesting.getPrice(), price, "Price should not have changed yet");
        } else {
            console.log("Current price: ", crowdinvesting.getPrice());
            console.log("Max price: ", priceMax);
            console.log("price plus increase: ", price + priceIncreasePerDuration);
            assertTrue(crowdinvesting.getPrice() <= priceMax, "Price too high!");
            assertTrue(crowdinvesting.getPrice() >= priceMin, "Price too low!");
        }

        // check if the price actually changed
        vm.warp(uint256(startDate) + duration);
        console.log("Current price: ", crowdinvesting.getPrice());
        assertTrue(crowdinvesting.getPrice() > price, "Price should have changed!");
    }

    function testActivateDynamicPricingWithAddress0Reverts() public {
        // activate dynamic pricing
        vm.startPrank(owner);
        crowdinvesting.pause();
        vm.expectRevert("_priceOracle can not be zero address");
        crowdinvesting.activateDynamicPricing(IPriceDynamic(address(0)), priceMin, priceMax);
    }

    function testDeactivateDynamicPricing() public {
        // create oracle
        vm.warp(1 hours + 1); // otherwise, price linear thinks it has to cool down
        PriceLinear priceLinear = PriceLinear(
            priceLinearCloneFactory.createPriceLinearClone(
                0,
                trustedForwarder,
                owner,
                1e5,
                1,
                2 hours,
                1,
                false,
                true // price will fall
            )
        );

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            owner,
            payable(receiver),
            minAmountPerBuyer,
            maxAmountPerBuyer,
            price,
            priceMin,
            priceMax,
            maxAmountOfTokenToBeSold,
            paymentToken,
            token,
            0,
            address(priceLinear)
        );

        crowdinvesting = Crowdinvesting(factory.createCrowdinvestingClone(0, trustedForwarder, arguments));

        vm.warp(100 days);

        // check that price is changed by oracle
        assertTrue(crowdinvesting.getPrice() > price, "Price should have changed!");

        // disable dynamic pricing
        vm.startPrank(owner);
        crowdinvesting.pause();
        crowdinvesting.deactivateDynamicPricing();
        vm.warp(block.timestamp + crowdinvesting.delay() + 1);
        crowdinvesting.unpause();

        // check that price is not changed anymore
        assertTrue(crowdinvesting.getPrice() == price, "Price should not have changed!");
    }

    function testActivateDynamicPricingOnDeployAndEnforceMinPrice(
        uint64 priceChangePerDuration,
        uint64 duration,
        uint64 startDate,
        uint64 testDate
    ) public {
        vm.assume(priceChangePerDuration > 0);
        vm.assume(duration > 0);
        vm.assume(startDate > 1 hours + 1);
        vm.assume(testDate > 0);

        // create oracle
        vm.warp(1 hours + 1); // otherwise, price linear thinks it has to cool down
        PriceLinear priceLinear = PriceLinear(
            priceLinearCloneFactory.createPriceLinearClone(
                0,
                trustedForwarder,
                owner,
                priceChangePerDuration,
                duration,
                startDate,
                1,
                false,
                false // price will fall
            )
        );

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            owner,
            payable(receiver),
            minAmountPerBuyer,
            maxAmountPerBuyer,
            price,
            priceMin,
            priceMax,
            maxAmountOfTokenToBeSold,
            paymentToken,
            token,
            0,
            address(priceLinear)
        );

        crowdinvesting = Crowdinvesting(factory.createCrowdinvestingClone(0, trustedForwarder, arguments));

        // check dynamic pricing
        if (block.timestamp < startDate) {
            // price can not change before start date
            console.log("Start date not reached yet: ", startDate);
            console.log("Current price: ", crowdinvesting.getPrice());
            assertEq(crowdinvesting.getPrice(), price, "Price should not have changed yet");
        } else {
            // price can never exceed bounds
            console.log("Current price: ", crowdinvesting.getPrice());
            console.log("Min price: ", priceMin);
            console.log("price plus increase: ", price + priceChangePerDuration);
            assertTrue(crowdinvesting.getPrice() >= priceMin, "Price too low!");
            assertTrue(crowdinvesting.getPrice() <= priceMax, "Price too high!");
        }

        // check if the price actually changed
        vm.warp(uint256(startDate) + duration);
        console.log("Current price: ", crowdinvesting.getPrice());
        assertTrue(crowdinvesting.getPrice() < price, "Price should have changed!");
    }

    function testActivateDynamicPricingOnDeployFixed() public {
        uint64 priceChangePerDuration = uint64(1 * 10 ** paymentTokenDecimals);
        uint64 duration = 1 days;
        uint64 startDate = 2000000000; // Wednesday, 18. May 2033 03:33:20
        uint32 stepWidth = 1 hours;

        // with these parameters, the price should change every hour for 93 days until it reaches 100e6

        // create oracle
        PriceLinear priceLinear = PriceLinear(
            priceLinearCloneFactory.createPriceLinearClone(
                0,
                trustedForwarder,
                owner,
                priceChangePerDuration,
                duration,
                startDate,
                stepWidth,
                false,
                true // price will rise
            )
        );

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            owner,
            payable(receiver),
            minAmountPerBuyer,
            maxAmountPerBuyer,
            price,
            priceMin,
            priceMax,
            maxAmountOfTokenToBeSold,
            paymentToken,
            token,
            0,
            address(priceLinear)
        );

        crowdinvesting = Crowdinvesting(factory.createCrowdinvestingClone(0, trustedForwarder, arguments));

        // check dynamic pricing
        vm.warp(uint256(startDate));
        assertEq(crowdinvesting.getPrice(), price, "Price should not have changed yet 1");

        vm.warp(uint256(startDate) + stepWidth - 1);
        assertEq(crowdinvesting.getPrice(), price, "Price should not have changed yet 2");

        vm.warp(uint256(startDate) + stepWidth);
        assertEq(
            crowdinvesting.getPrice(),
            price + (priceChangePerDuration * stepWidth) / duration,
            "Price should have changed by 1 step 1"
        );

        vm.warp(uint256(startDate) + stepWidth + 45 minutes);
        assertEq(
            crowdinvesting.getPrice(),
            price + (priceChangePerDuration * stepWidth) / duration,
            "Price should have changed by 1 step 2"
        );

        vm.warp(uint256(startDate) + 3 * stepWidth);
        assertEq(
            crowdinvesting.getPrice(),
            price + (3 * (priceChangePerDuration * stepWidth)) / duration,
            "Price should have changed by 3 steps"
        );

        vm.warp(uint256(startDate) + 100 * stepWidth - 1);
        assertEq(
            crowdinvesting.getPrice(),
            price + (99 * (priceChangePerDuration * stepWidth)) / duration,
            "Price should have changed by 99 steps"
        );

        vm.warp(uint256(startDate) + duration); // after 1 day, price changed by priceChangePerDuration
        assertEq(
            crowdinvesting.getPrice(),
            price + priceChangePerDuration,
            "Price should have changed by 10 * 24 steps"
        );

        // I need to check manually, too
        assertEq(crowdinvesting.getPrice(), 8e6, "Price should be 8e6 now");

        vm.warp(uint256(startDate) + 93 * duration - 1); // after 93 days, price changed by 93 * priceChangePerDuration
        assertEq(
            crowdinvesting.getPrice(),
            price + ((92 * 24 + 23) * (priceChangePerDuration * stepWidth)) / duration,
            "This should be the last second with a slightly cheaper price 1"
        );
        assertTrue(
            crowdinvesting.getPrice() < priceMax,
            "This should be the last second with a slightly cheaper price 2"
        );

        vm.warp(uint256(startDate) + 93 * duration); // after 93 days, price is limited by priceMax
        assertEq(crowdinvesting.getPrice(), priceMax, "Price should be priceMax now");

        vm.warp(uint256(startDate) + 3000 days); // after 93 days, price is limited by priceMax
        assertEq(crowdinvesting.getPrice(), priceMax, "Price should be priceMax now");

        vm.warp(type(uint64).max);
        assertEq(crowdinvesting.getPrice(), priceMax, "Price should be priceMax now");
    }

    function testChangingPriceDisablesPriceDynamic() public {
        // create oracle
        vm.warp(1 hours + 1); // otherwise, price linear thinks it has to cool down
        PriceLinear priceLinear = PriceLinear(
            priceLinearCloneFactory.createPriceLinearClone(
                0,
                trustedForwarder,
                owner,
                1e10,
                1,
                2 hours,
                1,
                false,
                true // price will rise
            )
        );

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            owner,
            payable(receiver),
            minAmountPerBuyer,
            maxAmountPerBuyer,
            price,
            priceMin,
            priceMax,
            maxAmountOfTokenToBeSold,
            paymentToken,
            token,
            0,
            address(priceLinear)
        );

        crowdinvesting = Crowdinvesting(factory.createCrowdinvestingClone(0, trustedForwarder, arguments));

        vm.warp(200 days);

        console.log("Oracle address: ", address(crowdinvesting.priceOracle()));
        console.log("Price through oracle: ", priceLinear.getPrice(price));
        console.log("Price through crowdinvesting: ", crowdinvesting.getPrice());
        // check that price is changed by oracle
        assertTrue(crowdinvesting.priceBase() == price, "Price not as expected");
        assertTrue(crowdinvesting.getPrice() > price, "Price should have changed!");

        // change price
        vm.startPrank(owner);
        crowdinvesting.pause();
        crowdinvesting.setCurrencyAndTokenPrice(IERC20(address(20)), price / 2);
        vm.warp(201 days);
        crowdinvesting.unpause();

        // check that price is not changed anymore
        assertTrue(crowdinvesting.getPrice() == price / 2, "Price should not have changed!");
        assertTrue(crowdinvesting.priceBase() == price / 2, "Token price should have changed!");
    }
}
