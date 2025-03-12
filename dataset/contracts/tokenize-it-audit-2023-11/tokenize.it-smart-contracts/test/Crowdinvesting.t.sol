// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/FeeSettings.sol";
import "../contracts/factories/CrowdinvestingCloneFactory.sol";
import "./resources/FakePaymentToken.sol";
import "./resources/MaliciousPaymentToken.sol";
import "./resources/FakeCrowdinvestingAndToken.sol";
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

    MaliciousPaymentToken maliciousPaymentToken;

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

    uint256 public constant price = 7 * 10 ** paymentTokenDecimals; // 7 payment tokens per token

    uint256 public constant maxAmountOfTokenToBeSold = 20 * 10 ** 18; // 20 token
    uint256 public constant maxAmountPerBuyer = maxAmountOfTokenToBeSold / 2; // 10 token
    uint256 public constant minAmountPerBuyer = maxAmountOfTokenToBeSold / 200; // 0.1 token

    uint256 public constant lastBuyDate = 12859023;

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

    function testLogicContractCreation() public {
        Crowdinvesting _logic = new Crowdinvesting(address(1));

        console.log("address of logic contract: ", address(_logic));

        // try to initialize
        vm.expectRevert("Initializable: contract is already initialized");
        _logic.initialize(
            CrowdinvestingInitializerArguments(
                address(this),
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
            )
        );

        // owner and all settings are 0
        assertTrue(_logic.owner() == address(0), "owner is not 0");
        assertTrue(_logic.currencyReceiver() == address(0));
        assertTrue(_logic.minAmountPerBuyer() == 0);
        assertTrue(_logic.maxAmountPerBuyer() == 0);
        assertTrue(_logic.priceBase() == 0);
        assertTrue(address(_logic.currency()) == address(0));
        assertTrue(address(_logic.token()) == address(0));
    }

    function testConstructorHappyCase() public {
        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            address(this),
            payable(receiver),
            minAmountPerBuyer,
            maxAmountPerBuyer,
            price,
            price,
            price,
            maxAmountOfTokenToBeSold,
            paymentToken,
            token,
            lastBuyDate,
            address(0)
        );
        Crowdinvesting _crowdinvesting = Crowdinvesting(
            factory.createCrowdinvestingClone(0, trustedForwarder, arguments)
        );
        assertTrue(_crowdinvesting.owner() == address(this));
        assertTrue(_crowdinvesting.currencyReceiver() == receiver);
        assertTrue(_crowdinvesting.minAmountPerBuyer() == minAmountPerBuyer);
        assertTrue(_crowdinvesting.maxAmountPerBuyer() == maxAmountPerBuyer);
        assertTrue(_crowdinvesting.maxAmountOfTokenToBeSold() == maxAmountOfTokenToBeSold);
        assertTrue(_crowdinvesting.priceBase() == price);
        assertTrue(_crowdinvesting.currency() == paymentToken);
        assertTrue(_crowdinvesting.token() == token);
        assertTrue(_crowdinvesting.lastBuyDate() == lastBuyDate);
    }

    function testConstructorWithBadArguments() public {
        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            address(this),
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
        vm.expectRevert("CrowdinvestingCloneFactory: Unexpected trustedForwarder");
        Crowdinvesting(factory.createCrowdinvestingClone(0, address(0), arguments));

        // owner 0
        CrowdinvestingInitializerArguments memory tempArgs = cloneCrowdinvestingInitializerArguments(arguments);
        tempArgs.owner = address(0);
        vm.expectRevert("owner can not be zero address");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);

        // receiver 0
        tempArgs = cloneCrowdinvestingInitializerArguments(arguments);
        tempArgs.currencyReceiver = address(0);
        vm.expectRevert("currencyReceiver can not be zero address");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);

        // token minAmount > maxAmountPerBuyer
        tempArgs = cloneCrowdinvestingInitializerArguments(arguments);
        tempArgs.minAmountPerBuyer = maxAmountPerBuyer + 1;
        vm.expectRevert("_minAmountPerBuyer needs to be smaller or equal to _maxAmountPerBuyer");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);

        // price 0
        tempArgs = cloneCrowdinvestingInitializerArguments(arguments);
        tempArgs.tokenPrice = 0;
        vm.expectRevert("_tokenPrice needs to be a non-zero amount");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);

        // max price 0
        tempArgs = cloneCrowdinvestingInitializerArguments(arguments);
        tempArgs.priceMax = 0;
        tempArgs.priceOracle = address(3);
        vm.expectRevert("priceMax needs to be larger or equal to priceBase");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);

        // min price too high
        tempArgs.priceMax = price;
        tempArgs.priceMin = price + 1;
        vm.expectRevert("priceMin needs to be smaller or equal to priceBase");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);

        // token maxAmountToBeSold 0
        tempArgs = cloneCrowdinvestingInitializerArguments(arguments);
        tempArgs.maxAmountOfTokenToBeSold = 0;
        vm.expectRevert("_maxAmountOfTokenToBeSold needs to be larger than zero");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);

        // currency 0
        tempArgs = cloneCrowdinvestingInitializerArguments(arguments);
        tempArgs.currency = IERC20(address(0));
        vm.expectRevert("currency can not be zero address");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);

        // token 0
        tempArgs = cloneCrowdinvestingInitializerArguments(arguments);
        tempArgs.token = Token(address(0));
        vm.expectRevert("token can not be zero address");
        factory.createCrowdinvestingClone(0, trustedForwarder, tempArgs);
    }

    /*
    set up with MaliciousPaymentToken which tries to reenter the buy function
    */
    function testReentrancy() public {
        uint8 _paymentTokenDecimals = 18;

        /*
        _paymentToken: 1 FPT = 10**_paymentTokenDecimals FPTbits (bit = smallest subunit of token)
        Token: 1 CT = 10**18 CTbits
        price definition: 30FPT buy 1CT, but must be expressed in FPTbits/CT
        price = 30 * 10**_paymentTokenDecimals
        */

        uint256 _price = 7 * 10 ** _paymentTokenDecimals;
        uint256 _maxMintAmount = 1000 * 10 ** 18; // 2**256 - 1; // need maximum possible value because we are using a fake token with variable decimals
        uint256 _paymentTokenAmount = 100000 * 10 ** _paymentTokenDecimals;

        list = createAllowList(trustedForwarder, owner);
        Token _token = Token(
            tokenCloneFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                admin,
                list,
                0x0,
                "REENTRANCYTOKEN",
                "TEST"
            )
        );
        vm.prank(paymentTokenProvider);
        maliciousPaymentToken = new MaliciousPaymentToken(_paymentTokenAmount);
        vm.prank(owner);

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            address(this),
            payable(receiver),
            1,
            _maxMintAmount / 100,
            _price,
            _price,
            _price,
            _maxMintAmount,
            maliciousPaymentToken,
            _token,
            0,
            address(0)
        );

        Crowdinvesting _crowdinvesting = Crowdinvesting(
            factory.createCrowdinvestingClone(0, trustedForwarder, arguments)
        );

        // allow invite contract to mint
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        _token.grantRole(roleMintAllower, mintAllower);
        vm.startPrank(mintAllower);
        _token.increaseMintingAllowance(
            address(_crowdinvesting),
            _maxMintAmount - token.mintingAllowance(address(_crowdinvesting))
        );
        vm.stopPrank();

        // mint _paymentToken for buyer
        vm.prank(paymentTokenProvider);
        maliciousPaymentToken.transfer(buyer, _paymentTokenAmount);
        assertTrue(maliciousPaymentToken.balanceOf(buyer) == _paymentTokenAmount);

        // set exploitTarget
        maliciousPaymentToken.setExploitTarget(address(_crowdinvesting), 3, _maxMintAmount / 200000);

        // give invite contract allowance
        vm.prank(buyer);
        maliciousPaymentToken.approve(address(_crowdinvesting), _paymentTokenAmount);

        // store some state
        //uint buyerPaymentBalanceBefore = _paymentToken.balanceOf(buyer);

        // run actual test
        assertTrue(maliciousPaymentToken.balanceOf(buyer) == _paymentTokenAmount);
        uint256 buyAmount = _maxMintAmount / 100000;
        vm.prank(buyer);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        _crowdinvesting.buy(buyAmount, buyer);
    }

    function testBuyHappyCase(uint256 tokenBuyAmount) public {
        vm.assume(tokenBuyAmount >= crowdinvesting.minAmountPerBuyer());
        vm.assume(tokenBuyAmount <= crowdinvesting.maxAmountPerBuyer());
        uint256 costInPaymentToken = Math.ceilDiv(tokenBuyAmount * crowdinvesting.priceBase(), 10 ** 18);
        vm.assume(costInPaymentToken <= paymentToken.balanceOf(buyer));

        uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(buyer);

        FeeSettings localFeeSettings = FeeSettings(address(token.feeSettings()));
        FakeCrowdinvesting fakeCrowdinvesting = new FakeCrowdinvesting(address(token));

        vm.prank(buyer);
        vm.expectEmit(true, true, true, true, address(crowdinvesting));
        emit TokensBought(buyer, tokenBuyAmount, costInPaymentToken);
        crowdinvesting.buy(tokenBuyAmount, buyer);
        assertTrue(paymentToken.balanceOf(buyer) == paymentTokenBalanceBefore - costInPaymentToken, "buyer has paid");
        assertTrue(token.balanceOf(buyer) == tokenBuyAmount, "buyer has tokens");
        assertTrue(
            paymentToken.balanceOf(receiver) == costInPaymentToken - fakeCrowdinvesting.fee(costInPaymentToken),
            "receiver has payment tokens"
        );
        assertTrue(
            paymentToken.balanceOf(
                FeeSettings(address(token.feeSettings())).crowdinvestingFeeCollector(address(token))
            ) == fakeCrowdinvesting.fee(costInPaymentToken),
            "fee collector has collected fee in payment tokens"
        );
        assertTrue(
            token.balanceOf(FeeSettings(address(token.feeSettings())).tokenFeeCollector(address(token))) ==
                localFeeSettings.tokenFee(tokenBuyAmount),
            "fee collector has collected fee in tokens"
        );
        assertTrue(crowdinvesting.tokensSold() == tokenBuyAmount, "crowdinvesting has sold tokens");
        assertTrue(crowdinvesting.tokensBought(buyer) == tokenBuyAmount, "crowdinvesting has sold tokens to buyer");
    }

    function testBuyTooMuch() public {
        uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        vm.expectRevert("Total amount of bought tokens needs to be lower than or equal to maxAmount");
        crowdinvesting.buy(maxAmountPerBuyer + 10 ** 18, buyer); //+ 10**token.decimals());
        assertTrue(paymentToken.balanceOf(buyer) == paymentTokenBalanceBefore);
        assertTrue(token.balanceOf(buyer) == 0);
        assertTrue(paymentToken.balanceOf(receiver) == 0);
        assertTrue(crowdinvesting.tokensSold() == 0);
        assertTrue(crowdinvesting.tokensBought(buyer) == 0);
    }

    function testBuyAndMintToDifferentAddress() public {
        address addressWithFunds = vm.addr(1);
        address addressForTokens = vm.addr(2);

        uint256 availableBalance = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        paymentToken.transfer(addressWithFunds, availableBalance / 2);

        vm.prank(addressWithFunds);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        // check state before
        assertTrue(paymentToken.balanceOf(addressWithFunds) == availableBalance / 2, "addressWithFunds has no funds");
        assertTrue(paymentToken.balanceOf(addressForTokens) == 0, "addressForTokens has funds");
        assertTrue(token.balanceOf(addressForTokens) == 0, "addressForTokens has tokens before buy");
        assertTrue(token.balanceOf(addressWithFunds) == 0, "addressWithFunds has tokens before buy");

        // execute buy, with addressForTokens as recipient
        vm.prank(addressWithFunds);
        crowdinvesting.buy(maxAmountOfTokenToBeSold / 2, addressForTokens);

        // check state after
        console.log("addressWithFunds balance: ", paymentToken.balanceOf(addressWithFunds));
        assertTrue(
            paymentToken.balanceOf(addressWithFunds) <=
                availableBalance / 2 - paymentToken.balanceOf(crowdinvesting.currencyReceiver()),
            "addressWithFunds has funds after buy"
        );
        assertTrue(paymentToken.balanceOf(addressForTokens) == 0, "addressForTokens has funds after buy");
        assertTrue(
            token.balanceOf(addressForTokens) == maxAmountOfTokenToBeSold / 2,
            "addressForTokens has wrong amount of tokens after buy"
        );
        assertTrue(token.balanceOf(addressWithFunds) == 0, "addressWithFunds has tokens after buy");
    }

    function testMultiplePeopleBuyTooMuch() public {
        address person1 = vm.addr(1);
        address person2 = vm.addr(2);

        uint256 availableBalance = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        paymentToken.transfer(person1, availableBalance / 3);
        vm.prank(buyer);
        paymentToken.transfer(person2, availableBalance / 3);

        vm.prank(person1);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        vm.prank(person2);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        vm.prank(buyer);
        crowdinvesting.buy(maxAmountOfTokenToBeSold / 2, buyer);
        vm.prank(person1);
        crowdinvesting.buy(maxAmountOfTokenToBeSold / 2, person1);
        vm.prank(person2);
        vm.expectRevert("Not enough tokens to sell left");
        crowdinvesting.buy(10 ** 18, person2);
    }

    function testMultipleAddressesBuyForOneReceiver() public {
        address person1 = vm.addr(1);
        address person2 = vm.addr(2);

        uint256 availableBalance = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        paymentToken.transfer(person1, availableBalance / 2);
        vm.prank(buyer);
        paymentToken.transfer(person2, 10 ** 6);

        vm.prank(person1);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        vm.prank(person2);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        vm.prank(buyer);
        crowdinvesting.buy(maxAmountOfTokenToBeSold / 2, buyer);
        vm.prank(person1);
        vm.expectRevert("Total amount of bought tokens needs to be lower than or equal to maxAmount");
        crowdinvesting.buy(maxAmountOfTokenToBeSold / 2, buyer);
    }

    function testCorrectAccounting() public {
        address person1 = vm.addr(1);
        address person2 = vm.addr(2);

        uint256 availableBalance = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        paymentToken.transfer(person1, availableBalance / 2);
        vm.prank(buyer);
        paymentToken.transfer(person2, 10 ** 6);

        vm.prank(person1);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        vm.prank(person2);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        // check all entries are 0 before
        assertTrue(crowdinvesting.tokensSold() == 0);
        assertTrue(crowdinvesting.tokensBought(buyer) == 0);
        assertTrue(crowdinvesting.tokensBought(person1) == 0);
        assertTrue(crowdinvesting.tokensBought(person2) == 0);

        vm.prank(buyer);
        crowdinvesting.buy(maxAmountOfTokenToBeSold / 2, buyer);
        vm.prank(buyer);
        crowdinvesting.buy(maxAmountOfTokenToBeSold / 4, person1);
        vm.prank(buyer);
        crowdinvesting.buy(maxAmountOfTokenToBeSold / 8, person2);

        // check all entries are correct after
        assertTrue(crowdinvesting.tokensSold() == (maxAmountOfTokenToBeSold * 7) / 8);
        assertTrue(crowdinvesting.tokensBought(buyer) == maxAmountOfTokenToBeSold / 2);
        assertTrue(crowdinvesting.tokensBought(person1) == maxAmountOfTokenToBeSold / 4);
        assertTrue(crowdinvesting.tokensBought(person2) == maxAmountOfTokenToBeSold / 8);
        assertTrue(token.balanceOf(buyer) == maxAmountOfTokenToBeSold / 2);
        assertTrue(token.balanceOf(person1) == maxAmountOfTokenToBeSold / 4);
        assertTrue(token.balanceOf(person2) == maxAmountOfTokenToBeSold / 8);
    }

    function testExceedMintingAllowance() public {
        // reduce minting allowance of fundraising contract, so the revert happens in Token
        vm.startPrank(mintAllower);
        token.decreaseMintingAllowance(
            address(crowdinvesting),
            token.mintingAllowance(address(crowdinvesting)) - (maxAmountPerBuyer / 2)
        );
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("MintingAllowance too low");
        crowdinvesting.buy(maxAmountPerBuyer, buyer); //+ 10**token.decimals());
        assertTrue(token.balanceOf(buyer) == 0);
        assertTrue(paymentToken.balanceOf(receiver) == 0);
        assertTrue(crowdinvesting.tokensSold() == 0);
        assertTrue(crowdinvesting.tokensBought(buyer) == 0);
    }

    function testBuyTooLittle() public {
        uint256 tokenBuyAmount = 5 * 10 ** token.decimals();
        uint256 costInPaymentToken = (tokenBuyAmount * price) / 10 ** 18;

        assert(costInPaymentToken == 35 * 10 ** paymentTokenDecimals); // 35 payment tokens, manually calculated

        uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        vm.expectRevert("Buyer needs to buy at least minAmount");
        crowdinvesting.buy(minAmountPerBuyer / 2, buyer);
        assertTrue(paymentToken.balanceOf(buyer) == paymentTokenBalanceBefore);
        assertTrue(token.balanceOf(buyer) == 0);
        assertTrue(paymentToken.balanceOf(receiver) == 0);
        assertTrue(crowdinvesting.tokensSold() == 0);
        assertTrue(crowdinvesting.tokensBought(buyer) == 0);
    }

    function testBuySmallAmountAfterInitialInvestment() public {
        uint256 tokenBuyAmount = minAmountPerBuyer;
        uint256 costInPaymentTokenForMinAmount = (tokenBuyAmount * price) / 10 ** 18;
        uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        crowdinvesting.buy(minAmountPerBuyer, buyer);

        // buy less than minAmount -> should be okay because minAmount has already been bought.
        vm.prank(buyer);
        crowdinvesting.buy(minAmountPerBuyer / 2, buyer);

        assertTrue(
            paymentToken.balanceOf(buyer) == paymentTokenBalanceBefore - (costInPaymentTokenForMinAmount * 3) / 2,
            "buyer has payment tokens"
        );
        assertTrue(token.balanceOf(buyer) == (minAmountPerBuyer * 3) / 2, "buyer has tokens");
        uint256 tokenFee = (minAmountPerBuyer * 3) /
            2 /
            FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator();
        uint256 paymentTokenFee = (costInPaymentTokenForMinAmount * 3) /
            2 /
            FeeSettings(address(token.feeSettings())).defaultCrowdinvestingFeeDenominator();
        assertTrue(
            paymentToken.balanceOf(receiver) == (costInPaymentTokenForMinAmount * 3) / 2 - paymentTokenFee,
            "receiver received payment tokens"
        );
        assertEq(
            token.balanceOf(FeeSettings(address(token.feeSettings())).tokenFeeCollector(address(token))),
            tokenFee,
            "fee collector has not collected fee in tokens"
        );
        assertEq(
            paymentToken.balanceOf(
                FeeSettings(address(token.feeSettings())).crowdinvestingFeeCollector(address(token))
            ),
            paymentTokenFee,
            "fee collector has not collected fee in payment tokens"
        );
        assertTrue(crowdinvesting.tokensSold() == (minAmountPerBuyer * 3) / 2, "crowdinvesting has sold tokens");
        assertTrue(
            crowdinvesting.tokensBought(buyer) == crowdinvesting.tokensSold(),
            "crowdinvesting has sold tokens to buyer"
        );
    }

    function ensureRealCostIsHigherEqualAdvertisedCost(uint256 tokenBuyAmount) public {
        uint256 _price = 1; // price = 1 currency bit per full token (10**18 token bits)

        // set price that is finer than the resolution of the payment token
        vm.startPrank(owner);
        crowdinvesting.pause();
        crowdinvesting.setCurrencyAndTokenPrice(crowdinvesting.currency(), _price);
        crowdinvesting.setMinAmountPerBuyer(1); // min amount = 1 currency bit
        vm.warp(block.timestamp + 1 days + 1 seconds);
        crowdinvesting.unpause();
        vm.stopPrank();

        // this is rounded down and resolves to 0 cost in payment token
        uint256 naiveCostInPaymentToken = (tokenBuyAmount * _price) / 10 ** 18;
        console.log("naiveCostInPaymentToken", naiveCostInPaymentToken);
        //assertTrue(naiveCostInPaymentToken == 0, "Naive cost is not 0"); // 35 payment tokens, manually calculated

        uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        crowdinvesting.buy(tokenBuyAmount, buyer);

        console.log("paymentTokenBalanceBefore", paymentTokenBalanceBefore);
        console.log("paymentToken.balanceOf(buyer)", paymentToken.balanceOf(buyer));

        uint256 realCostInPaymentToken = paymentTokenBalanceBefore - paymentToken.balanceOf(buyer);
        uint256 realPrice = (realCostInPaymentToken * 10 ** 18) / token.balanceOf(buyer);
        console.log("realCostInPaymentToken", realCostInPaymentToken);
        console.log("token.balanceOf(buyer)", token.balanceOf(buyer));
        console.log("advertised price: ", crowdinvesting.priceBase());
        console.log("real price: ", realPrice);
        assertTrue(token.balanceOf(buyer) == tokenBuyAmount, "buyer has not received tokens");
        assertTrue(paymentToken.balanceOf(receiver) >= 1, "receiver has not received any payment");
        assertTrue(realCostInPaymentToken >= 1, "real cost is 0, but should be at least 1");
        assertTrue(realCostInPaymentToken - naiveCostInPaymentToken >= 0, "real cost is less than advertised cost");
        assertTrue(realCostInPaymentToken - naiveCostInPaymentToken <= 1, "more than 1 currency bit was rounded!");
        assertTrue(realPrice >= _price, "real price is less than advertised");
    }

    function testBuyAnyAmountRoundsUp(uint tokenBuyAmount) public {
        vm.assume(tokenBuyAmount < crowdinvesting.maxAmountPerBuyer());
        vm.assume(tokenBuyAmount > 0);
        ensureRealCostIsHigherEqualAdvertisedCost(tokenBuyAmount);
    }

    function testBuy1BitRoundsUp() public {
        // this will result in the naive cost being 0
        ensureRealCostIsHigherEqualAdvertisedCost(1);
    }

    /*
        try to buy more than allowed
    */
    function testFailOverflow() public {
        vm.prank(buyer);
        crowdinvesting.buy(maxAmountPerBuyer + 1, buyer);
    }

    /*
        try to buy less than allowed
    */
    function testFailUnderflow() public {
        vm.prank(buyer);
        crowdinvesting.buy(minAmountPerBuyer - 1, buyer);
    }

    /*
        try to buy while paused
    */
    function testFailPaused() public {
        vm.prank(owner);
        crowdinvesting.pause();
        vm.prank(buyer);
        crowdinvesting.buy(minAmountPerBuyer, buyer);
    }

    /*
        try to update currencyReceiver not paused
    */
    function testFailUpdateCurrencyReceiverNotPaused() public {
        vm.prank(owner);
        crowdinvesting.setCurrencyReceiver(payable(address(buyer)));
    }

    /*
        try to update currencyReceiver while paused
    */
    function testUpdateCurrencyReceiverPaused() public {
        assertTrue(crowdinvesting.currencyReceiver() == receiver);
        vm.prank(owner);
        crowdinvesting.pause();
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(crowdinvesting));
        emit CurrencyReceiverChanged(address(buyer));
        crowdinvesting.setCurrencyReceiver(address(buyer));
        assertTrue(crowdinvesting.currencyReceiver() == address(buyer));

        vm.prank(owner);
        vm.expectRevert("receiver can not be zero address");
        crowdinvesting.setCurrencyReceiver(address(0));
    }

    /* 
        try to update minAmountPerBuyer not paused
    */
    function testFailUpdateMinAmountPerBuyerNotPaused() public {
        vm.prank(owner);
        crowdinvesting.setMinAmountPerBuyer(100);
    }

    /* 
        try to update minAmountPerBuyer while paused
    */
    function testUpdateMinAmountPerBuyerPaused(uint256 newMinAmountPerBuyer) public {
        vm.assume(newMinAmountPerBuyer <= crowdinvesting.maxAmountPerBuyer());
        assertTrue(crowdinvesting.minAmountPerBuyer() == minAmountPerBuyer);
        vm.prank(owner);
        crowdinvesting.pause();
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(crowdinvesting));
        emit MinAmountPerBuyerChanged(newMinAmountPerBuyer);
        crowdinvesting.setMinAmountPerBuyer(newMinAmountPerBuyer);
        assertTrue(crowdinvesting.minAmountPerBuyer() == newMinAmountPerBuyer);

        uint256 _maxAmountPerBuyer = crowdinvesting.maxAmountPerBuyer();
        vm.expectRevert("_minAmount needs to be smaller or equal to maxAmount");
        vm.prank(owner);
        crowdinvesting.setMinAmountPerBuyer(_maxAmountPerBuyer + 1); //crowdinvesting.maxAmountPerBuyer() + 1);

        console.log("minAmount: ", crowdinvesting.minAmountPerBuyer());
        console.log("maxAmount: ", crowdinvesting.maxAmountPerBuyer());
    }

    /* 
        try to update maxAmountPerBuyer not paused
    */
    function testFailUpdateMaxAmountPerBuyerNotPaused() public {
        vm.prank(owner);
        crowdinvesting.setMaxAmountPerBuyer(100);
    }

    /* 
        try to update maxAmountPerBuyer while paused
    */
    function testUpdateMaxAmountPerBuyerPaused(uint256 newMaxAmountPerBuyer) public {
        vm.assume(newMaxAmountPerBuyer >= crowdinvesting.minAmountPerBuyer());
        assertTrue(crowdinvesting.maxAmountPerBuyer() == maxAmountPerBuyer);
        vm.prank(owner);
        crowdinvesting.pause();
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(crowdinvesting));
        emit MaxAmountPerBuyerChanged(newMaxAmountPerBuyer);
        crowdinvesting.setMaxAmountPerBuyer(newMaxAmountPerBuyer);
        assertTrue(crowdinvesting.maxAmountPerBuyer() == newMaxAmountPerBuyer);
        uint256 _minAmountPerBuyer = crowdinvesting.minAmountPerBuyer();
        vm.expectRevert("_maxAmount needs to be larger or equal to minAmount");
        vm.prank(owner);
        crowdinvesting.setMaxAmountPerBuyer(_minAmountPerBuyer - 1);
    }

    /*
        try to update currency and price while not paused
    */
    function testFailUpdateCurrencyAndPriceNotPaused() public {
        FakePaymentToken newPaymentToken = new FakePaymentToken(700, 3);
        vm.prank(owner);
        crowdinvesting.setCurrencyAndTokenPrice(newPaymentToken, 100);
    }

    /*
        try to update currency and price while paused
    */
    function testUpdateCurrencyAndPricePaused(uint256 newPrice) public {
        vm.assume(newPrice > 0);
        assertTrue(crowdinvesting.priceBase() == price);
        assertTrue(crowdinvesting.currency() == paymentToken);

        FakePaymentToken newPaymentToken = new FakePaymentToken(700, 3);

        vm.prank(owner);
        crowdinvesting.pause();
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(crowdinvesting));
        emit TokenPriceAndCurrencyChanged(newPrice, newPaymentToken);
        crowdinvesting.setCurrencyAndTokenPrice(newPaymentToken, newPrice);
        assertTrue(crowdinvesting.priceBase() == newPrice);
        assertTrue(crowdinvesting.currency() == newPaymentToken);
        vm.prank(owner);
        vm.expectRevert("_tokenPrice needs to be a non-zero amount");
        crowdinvesting.setCurrencyAndTokenPrice(paymentToken, 0);
    }

    /*
        try to update maxAmountOfTokenToBeSold while not paused
    */
    function testFailUpdateMaxAmountOfTokenToBeSoldNotPaused() public {
        vm.prank(owner);
        crowdinvesting.setMaxAmountOfTokenToBeSold(123 * 10 ** 18);
    }

    /*
        try to update maxAmountOfTokenToBeSold while paused
    */
    function testUpdateMaxAmountOfTokenToBeSoldPaused(uint256 newMaxAmountOfTokenToBeSold) public {
        vm.assume(newMaxAmountOfTokenToBeSold > 0);
        assertTrue(crowdinvesting.maxAmountOfTokenToBeSold() == maxAmountOfTokenToBeSold);
        vm.prank(owner);
        crowdinvesting.pause();
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(crowdinvesting));
        emit MaxAmountOfTokenToBeSoldChanged(newMaxAmountOfTokenToBeSold);
        crowdinvesting.setMaxAmountOfTokenToBeSold(newMaxAmountOfTokenToBeSold);
        assertTrue(crowdinvesting.maxAmountOfTokenToBeSold() == newMaxAmountOfTokenToBeSold);
        vm.prank(owner);
        vm.expectRevert("_maxAmountOfTokenToBeSold needs to be larger than zero");
        crowdinvesting.setMaxAmountOfTokenToBeSold(0);
    }

    /*
        try to unpause immediately after pausing
    */
    function testFailUnpauseImmediatelyAfterPausing() public {
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());
        assertTrue(crowdinvesting.coolDownStart() > 0);
        vm.prank(owner);
        crowdinvesting.unpause();
    }

    /*
        try to unpause after delay has passed
    */
    function testUnpauseAfterDelay() public {
        uint256 time = block.timestamp;
        vm.warp(time);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());
        vm.warp(time + crowdinvesting.delay());
        vm.prank(owner);
        crowdinvesting.unpause();
    }

    /*
        try to unpause after more than 1 day has passed
    */
    function testUnpauseAfterPause() public {
        uint256 time = 200 days;
        uint256 coolDownStart = crowdinvesting.coolDownStart();
        vm.warp(time);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());
        assertTrue(crowdinvesting.coolDownStart() == coolDownStart, "coolDownStart should not change with pause");
        vm.warp(time + 1 seconds);
        vm.prank(owner);
        crowdinvesting.unpause();
    }

    /*
        try to unpause too soon after setMaxAmountOfTokenToBeSold
    */
    function testUnpauseTooSoonAfterSetMaxAmountOfTokenToBeSold(
        uint128 startTime,
        uint32 changeDelay,
        uint32 attemptUnpauseDelay
    ) public {
        uint256 unpauseDelay = 1 hours;
        vm.assume(startTime < type(uint128).max / 2);
        vm.assume(startTime > 0);
        vm.assume(changeDelay > 0);
        vm.assume(attemptUnpauseDelay > 0);
        vm.assume(attemptUnpauseDelay < unpauseDelay + changeDelay);

        vm.warp(startTime);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused(), "crowdinvesting should be paused");
        vm.warp(startTime + changeDelay);
        vm.prank(owner);
        crowdinvesting.setMaxAmountOfTokenToBeSold(700);
        assertTrue(
            crowdinvesting.coolDownStart() == startTime + changeDelay,
            "coolDownStart should be startTime + changeDelay"
        );
        vm.warp(startTime + attemptUnpauseDelay);
        vm.prank(owner);
        console.log("current time: ", block.timestamp);
        console.log("unpause at: ", startTime + changeDelay + unpauseDelay);
        vm.expectRevert("There needs to be at minimum one day to change parameters");
        crowdinvesting.unpause(); // must fail because of the parameter update
    }

    /*
        try to unpause after setMaxAmountOfTokenToBeSold
    */
    function testUnpauseAfterSetMaxAmountOfTokenToBeSold() public {
        uint256 time = block.timestamp;
        vm.warp(time);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());
        vm.warp(time + 2 hours);
        vm.prank(owner);
        crowdinvesting.setMaxAmountOfTokenToBeSold(700);
        assertTrue(crowdinvesting.coolDownStart() == time + 2 hours);
        vm.warp(time + crowdinvesting.delay() + 2 hours + 1 seconds);
        vm.prank(owner);
        crowdinvesting.unpause();
    }

    /*
        try to unpause too soon after setCurrencyReceiver
    */
    function testUnpauseTooSoonAfterSetCurrencyReceiver(
        uint128 startTime,
        uint32 changeDelay,
        uint32 attemptUnpauseDelay,
        address newCurrencyReceiver
    ) public {
        uint256 unpauseDelay = crowdinvesting.delay();
        vm.assume(startTime < type(uint128).max / 2);
        vm.assume(startTime > 0);
        vm.assume(changeDelay > 0);
        vm.assume(attemptUnpauseDelay > 0);
        vm.assume(attemptUnpauseDelay < unpauseDelay + changeDelay);
        vm.assume(newCurrencyReceiver != address(0));

        vm.warp(startTime);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused(), "crowdinvesting should be paused");
        vm.warp(startTime + changeDelay);
        vm.prank(owner);
        crowdinvesting.setCurrencyReceiver(newCurrencyReceiver);
        assertTrue(
            crowdinvesting.coolDownStart() == startTime + changeDelay,
            "coolDownStart should be startTime + changeDelay"
        );
        vm.warp(startTime + attemptUnpauseDelay);
        vm.prank(owner);
        console.log("current time: ", block.timestamp);
        console.log("unpause at: ", startTime + changeDelay + unpauseDelay);
        vm.expectRevert("There needs to be at minimum one day to change parameters");
        crowdinvesting.unpause(); // must fail because of the parameter update
    }

    /*
        try to unpause after setCurrencyReceiver
    */
    function testUnpauseAfterSetCurrencyReceiver() public {
        uint256 time = block.timestamp;
        vm.warp(time);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());
        vm.warp(time + 2 hours);
        vm.prank(owner);
        crowdinvesting.setCurrencyReceiver(paymentTokenProvider);
        assertTrue(crowdinvesting.coolDownStart() == time + 2 hours);
        vm.warp(time + crowdinvesting.delay() + 2 hours + 1 seconds);
        vm.prank(owner);
        crowdinvesting.unpause();
    }

    /*
        try to unpause too soon after setMinAmountPerBuyer
    */
    function testUnpauseTooSoonAfterSetMinAmountPerBuyer(
        uint128 startTime,
        uint32 changeDelay,
        uint32 attemptUnpauseDelay,
        uint256 newMinAmountPerBuyer
    ) public {
        uint256 unpauseDelay = crowdinvesting.delay();
        vm.assume(startTime < type(uint128).max / 2);
        vm.assume(startTime > 0);
        vm.assume(changeDelay > 0);
        vm.assume(attemptUnpauseDelay > 0);
        vm.assume(attemptUnpauseDelay < unpauseDelay + changeDelay);
        vm.assume(newMinAmountPerBuyer > 0);
        vm.assume(newMinAmountPerBuyer <= crowdinvesting.maxAmountPerBuyer());

        vm.warp(startTime);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused(), "crowdinvesting should be paused");
        vm.warp(startTime + changeDelay);
        vm.prank(owner);
        crowdinvesting.setMinAmountPerBuyer(newMinAmountPerBuyer);
        assertTrue(
            crowdinvesting.coolDownStart() == startTime + changeDelay,
            "coolDownStart should be startTime + changeDelay"
        );
        vm.warp(startTime + attemptUnpauseDelay);
        vm.prank(owner);
        console.log("current time: ", block.timestamp);
        console.log("unpause at: ", startTime + changeDelay + unpauseDelay);
        vm.expectRevert("There needs to be at minimum one day to change parameters");
        crowdinvesting.unpause(); // must fail because of the parameter update
    }

    /*
        try to unpause after setMinAmountPerBuyer
    */
    function testUnpauseAfterSetMinAmountPerBuyer() public {
        uint256 time = block.timestamp;
        vm.warp(time);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());
        vm.warp(time + 2 hours);
        vm.prank(owner);
        crowdinvesting.setMinAmountPerBuyer(700);
        assertTrue(crowdinvesting.coolDownStart() == time + 2 hours);
        vm.warp(time + crowdinvesting.delay() + 2 hours + 1 seconds);
        vm.prank(owner);
        crowdinvesting.unpause();
    }

    /*
        try to unpause too soon after setMaxAmountPerBuyer
    */
    function testUnpauseTooSoonAfterSetMaxAmountPerBuyer(
        uint128 startTime,
        uint32 changeDelay,
        uint32 attemptUnpauseDelay,
        uint256 newMaxAmountPerBuyer
    ) public {
        uint256 unpauseDelay = crowdinvesting.delay();
        vm.assume(startTime < type(uint128).max / 2);
        vm.assume(startTime > 0);
        vm.assume(changeDelay > 0);
        vm.assume(attemptUnpauseDelay > 0);
        vm.assume(attemptUnpauseDelay < unpauseDelay + changeDelay);
        vm.assume(newMaxAmountPerBuyer >= crowdinvesting.minAmountPerBuyer());

        vm.warp(startTime);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused(), "crowdinvesting should be paused");
        vm.warp(startTime + changeDelay);
        vm.prank(owner);
        crowdinvesting.setMaxAmountPerBuyer(newMaxAmountPerBuyer);
        assertTrue(
            crowdinvesting.coolDownStart() == startTime + changeDelay,
            "coolDownStart should be startTime + changeDelay"
        );
        vm.warp(startTime + attemptUnpauseDelay);
        vm.prank(owner);
        console.log("current time: ", block.timestamp);
        console.log("unpause at: ", startTime + changeDelay + unpauseDelay);
        vm.expectRevert("There needs to be at minimum one day to change parameters");
        crowdinvesting.unpause(); // must fail because of the parameter update
    }

    /*
        try to unpause after setMaxAmountPerBuyer
    */
    function testUnpauseAfterSetMaxAmountPerBuyer() public {
        uint256 time = block.timestamp;
        vm.warp(time);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());
        vm.warp(time + 2 hours);
        vm.prank(owner);
        crowdinvesting.setMaxAmountPerBuyer(2 * minAmountPerBuyer);
        assertTrue(crowdinvesting.coolDownStart() == time + 2 hours);
        vm.warp(time + crowdinvesting.delay() + 2 hours + 1 seconds);
        vm.prank(owner);
        crowdinvesting.unpause();
    }

    // /*
    //     try to unpause too soon after setCurrencyAndTokenPrice
    // */
    // function testUnpauseTooSoonAfterSetCurrencyAndTokenPrice() public {
    //     uint256 time = block.timestamp;
    //     vm.warp(time);
    //     vm.prank(owner);
    //     crowdinvesting.pause();
    //     assertTrue(crowdinvesting.paused());
    //     assertTrue(crowdinvesting.coolDownStart() == time);
    //     vm.warp(time + 2 hours);
    //     vm.prank(owner);
    //     crowdinvesting.setCurrencyAndTokenPrice(paymentToken, 700);
    //     assertTrue(crowdinvesting.coolDownStart() == time + 2 hours);
    //     vm.warp(time + crowdinvesting.delay() + 1 hours);
    //     vm.prank(owner);
    //     vm.expectRevert("There needs to be at minimum one day to change parameters");
    //     crowdinvesting.unpause(); // must fail because of the parameter update
    // }

    /*
        try to unpause too soon after setCurrencyAndTokenPrice
    */
    function testUnpauseTooSoonAfterSetCurrencyAndTokenPrice(
        uint128 startTime,
        uint32 changeDelay,
        uint32 attemptUnpauseDelay,
        uint256 newTokenPrice
    ) public {
        uint256 unpauseDelay = crowdinvesting.delay();
        vm.assume(startTime < type(uint128).max / 2);
        vm.assume(startTime > 0);
        vm.assume(changeDelay > 0);
        vm.assume(attemptUnpauseDelay > 0);
        vm.assume(attemptUnpauseDelay < unpauseDelay + changeDelay);
        vm.assume(newTokenPrice > 0);

        vm.warp(startTime);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused(), "crowdinvesting should be paused");
        vm.warp(startTime + changeDelay);
        vm.prank(owner);
        crowdinvesting.setCurrencyAndTokenPrice(paymentToken, newTokenPrice);
        assertTrue(
            crowdinvesting.coolDownStart() == startTime + changeDelay,
            "coolDownStart should be startTime + changeDelay"
        );
        vm.warp(startTime + attemptUnpauseDelay);
        vm.prank(owner);
        console.log("current time: ", block.timestamp);
        console.log("unpause at: ", startTime + changeDelay + unpauseDelay);
        vm.expectRevert("There needs to be at minimum one day to change parameters");
        crowdinvesting.unpause(); // must fail because of the parameter update
    }

    /*
        try to unpause after setCurrencyAndTokenPrice
    */
    function testUnpauseAfterSetCurrencyAndTokenPrice() public {
        uint256 time = block.timestamp;
        vm.warp(time);
        vm.prank(owner);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());
        vm.warp(time + 2 hours);
        vm.prank(owner);
        crowdinvesting.setCurrencyAndTokenPrice(paymentToken, 700);
        assertTrue(crowdinvesting.coolDownStart() == time + 2 hours);
        vm.warp(time + crowdinvesting.delay() + 2 hours + 1 seconds);
        vm.prank(owner);
        crowdinvesting.unpause();
    }

    function testRevertsOnOverflow(uint256 _tokenBuyAmount, uint256 _price) public {
        vm.assume(_tokenBuyAmount > 0);
        vm.assume(_price > 0);
        vm.assume(UINT256_MAX / _price < _tokenBuyAmount); // this will cause an overflow on multiplication

        // new currency
        // set up currency
        vm.prank(paymentTokenProvider);
        paymentToken = new FakePaymentToken(UINT256_MAX, paymentTokenDecimals); // 1000 tokens with 6 decimals
        // transfer currency to buyer
        vm.prank(paymentTokenProvider);
        paymentToken.transfer(buyer, UINT256_MAX);

        // create the crowdinvesting contract
        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            address(this),
            payable(receiver),
            0,
            UINT256_MAX,
            _price,
            _price,
            _price,
            UINT256_MAX,
            paymentToken,
            token,
            0,
            address(0)
        );
        vm.prank(owner);
        crowdinvesting = Crowdinvesting(factory.createCrowdinvestingClone(0, trustedForwarder, arguments));

        // grant allowances
        vm.prank(mintAllower);
        token.increaseMintingAllowance(address(crowdinvesting), UINT256_MAX);
        vm.prank(buyer);
        paymentToken.increaseAllowance(address(crowdinvesting), UINT256_MAX);

        vm.expectRevert(); //("Arithmetic over/underflow"); //("Division or modulo by 0");
        vm.prank(buyer);
        crowdinvesting.buy(_tokenBuyAmount, buyer);
    }

    function testRoundsUp(uint256 _tokenBuyAmount, uint256 _price) public {
        vm.assume(_tokenBuyAmount > 0);
        vm.assume(_price > 0);
        vm.assume(UINT256_MAX / _price > _tokenBuyAmount); // this will cause an overflow on multiplication

        uint256 tokenDecimals = token.decimals();
        uint minCurrencyAmount = (_tokenBuyAmount * _price) / 10 ** tokenDecimals;
        console.log("minCurrencyAmount: %s", minCurrencyAmount);
        uint maxCurrencyAmount = minCurrencyAmount + 1;
        console.log("maxCurrencyAmount: %s", maxCurrencyAmount);

        // new currency
        // set up currency
        vm.prank(paymentTokenProvider);
        paymentToken = new FakePaymentToken(maxCurrencyAmount, paymentTokenDecimals); // 1000 tokens with 6 decimals
        // transfer currency to buyer
        vm.prank(paymentTokenProvider);
        paymentToken.transfer(buyer, maxCurrencyAmount);

        // create the crowdinvesting contract
        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            address(this),
            payable(receiver),
            _tokenBuyAmount,
            _tokenBuyAmount,
            _price,
            _price,
            _price,
            _tokenBuyAmount,
            paymentToken,
            token,
            0,
            address(0)
        );
        vm.prank(owner);
        crowdinvesting = Crowdinvesting(factory.createCrowdinvestingClone(0, trustedForwarder, arguments));

        // set fees to 0, otherwise extra currency is minted which causes an overflow
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        FeeSettings(address(token.feeSettings())).planFeeChange(fees);
        FeeSettings(address(token.feeSettings())).executeFeeChange();

        // grant allowances
        vm.prank(mintAllower);
        token.increaseMintingAllowance(address(crowdinvesting), _tokenBuyAmount);
        vm.prank(buyer);
        paymentToken.increaseAllowance(address(crowdinvesting), maxCurrencyAmount);

        vm.prank(buyer);
        crowdinvesting.buy(_tokenBuyAmount, buyer);

        // check that the buyer got the correct amount of tokens
        assertTrue(token.balanceOf(buyer) == _tokenBuyAmount, "buyer got wrong amount of tokens");
        // check that the crowdinvesting got the correct amount of currency
        assertTrue(
            paymentToken.balanceOf(receiver) <= maxCurrencyAmount,
            "crowdinvesting got wrong amount of currency"
        );
        assertTrue(
            paymentToken.balanceOf(receiver) >= minCurrencyAmount,
            "crowdinvesting got wrong amount of currency"
        );
    }

    function testTransferOwnership(address newOwner) public {
        vm.prank(owner);
        crowdinvesting.transferOwnership(newOwner);
        assertTrue(crowdinvesting.owner() == owner);

        vm.prank(newOwner);
        crowdinvesting.acceptOwnership();
        assertTrue(crowdinvesting.owner() == newOwner);
    }

    function testOfferExpiration(uint256 _lastBuyDate, uint256 testDate) public {
        vm.assume(testDate > 1 days + 1);
        vm.assume(testDate < 100 * 365 days);
        vm.assume(_lastBuyDate > 1);
        vm.assume(_lastBuyDate < 100 * 365 days);

        // because of limitations in the test suite, we have to decide on a fixed date to base our warping on
        uint256 startDate = 100 * 365 days;
        vm.warp(startDate);

        uint256 tokenBuyAmount = 5 * 10 ** token.decimals();
        uint256 costInPaymentToken = Math.ceilDiv(tokenBuyAmount * crowdinvesting.priceBase(), 10 ** 18);

        vm.startPrank(owner);
        crowdinvesting.pause();
        crowdinvesting.setLastBuyDate(startDate + _lastBuyDate);
        vm.warp(startDate + 1 days + 1);
        crowdinvesting.unpause();
        vm.stopPrank();

        vm.warp(startDate + testDate);

        // log block.timestamp and lastBuyDate
        console.log("block.timestamp: ", block.timestamp);
        console.log("lastBuyDate: ", _lastBuyDate);

        if (testDate > _lastBuyDate) {
            vm.expectRevert("Last buy date has passed: not selling tokens anymore.");
            vm.prank(buyer);
            crowdinvesting.buy(tokenBuyAmount, buyer);
        } else {
            vm.prank(buyer);
            vm.expectEmit(true, true, true, true, address(crowdinvesting));
            emit TokensBought(buyer, tokenBuyAmount, costInPaymentToken);
            crowdinvesting.buy(tokenBuyAmount, buyer);
        }
    }

    function testLastBuyDateInConstructor(uint256 _lastBuyDate, uint256 testDate) public {
        vm.assume(_lastBuyDate > 0);
        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            address(this),
            payable(receiver),
            minAmountPerBuyer,
            maxAmountPerBuyer,
            price,
            price,
            price,
            maxAmountOfTokenToBeSold,
            paymentToken,
            token,
            _lastBuyDate,
            address(0)
        );
        Crowdinvesting _crowdinvesting = Crowdinvesting(
            factory.createCrowdinvestingClone(0, trustedForwarder, arguments)
        );

        vm.warp(testDate);

        uint256 tokenBuyAmount = 5 * 10 ** token.decimals();
        uint256 costInPaymentToken = Math.ceilDiv(tokenBuyAmount * crowdinvesting.priceBase(), 10 ** 18);

        // log test date, auto pause date and block.timestamp
        console.log("testDate: ", testDate);
        console.log("lastBuyDate: ", _lastBuyDate);
        console.log("block.timestamp: ", block.timestamp);

        if (testDate > _lastBuyDate) {
            // auto-pause should trigger
            vm.startPrank(buyer);
            paymentToken.approve(address(_crowdinvesting), type(uint256).max);
            vm.expectRevert("Last buy date has passed: not selling tokens anymore.");
            _crowdinvesting.buy(tokenBuyAmount, buyer);
            vm.stopPrank();
        } else {
            // auto-pause should not trigger
            vm.prank(admin);
            token.increaseMintingAllowance(address(_crowdinvesting), maxAmountOfTokenToBeSold);

            vm.startPrank(buyer);
            paymentToken.approve(address(_crowdinvesting), type(uint256).max);
            vm.expectEmit(true, true, true, true, address(_crowdinvesting));
            emit TokensBought(buyer, tokenBuyAmount, costInPaymentToken);
            _crowdinvesting.buy(tokenBuyAmount, buyer);
            vm.stopPrank();
        }
    }

    function cloneCrowdinvestingInitializerArguments(
        CrowdinvestingInitializerArguments memory arguments
    ) public pure returns (CrowdinvestingInitializerArguments memory) {
        return
            CrowdinvestingInitializerArguments(
                arguments.owner,
                arguments.currencyReceiver,
                arguments.minAmountPerBuyer,
                arguments.maxAmountPerBuyer,
                arguments.tokenPrice,
                arguments.priceMin,
                arguments.priceMax,
                arguments.maxAmountOfTokenToBeSold,
                arguments.currency,
                arguments.token,
                arguments.lastBuyDate,
                arguments.priceOracle
            );
    }
}
