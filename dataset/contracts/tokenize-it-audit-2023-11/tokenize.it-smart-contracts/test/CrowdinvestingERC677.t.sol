// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
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
            receiver,
            minAmountPerBuyer,
            maxAmountPerBuyer,
            price,
            0,
            0,
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
            owner,
            receiver,
            minAmountPerBuyer,
            maxAmountPerBuyer,
            _price,
            0,
            0,
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

        // run actual test
        assertTrue(maliciousPaymentToken.balanceOf(buyer) == _paymentTokenAmount);
        uint256 buyAmount = _maxMintAmount / 100000;
        vm.prank(buyer);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        _crowdinvesting.buy(buyAmount, buyer);
    }

    function testERC677BuyHappyCase(uint256 tokenBuyAmount) public {
        // uint256 tokenBuyAmount = 10 ** token.decimals(); // buy one token
        vm.assume(tokenBuyAmount >= crowdinvesting.minAmountPerBuyer());
        vm.assume(tokenBuyAmount <= crowdinvesting.maxAmountPerBuyer());
        uint256 costInPaymentToken = Math.ceilDiv(tokenBuyAmount * crowdinvesting.priceBase(), 10 ** 18);
        vm.assume(costInPaymentToken <= paymentToken.balanceOf(buyer));

        uint256 realTokenBuyAmount = (costInPaymentToken * 10 ** token.decimals()) / crowdinvesting.getPrice();

        // log tokenBuyAmount and costInPaymentToken and price, realTokenBuyAmount
        console.log("tokenBuyAmount: ", tokenBuyAmount);
        console.log("costInPaymentToken: ", costInPaymentToken);
        console.log("tokenPrice: ", crowdinvesting.getPrice());
        console.log("realTokenBuyAmount: ", realTokenBuyAmount);
        // log price from realTokenBuyAmount and costInPaymentToken
        console.log(
            "price from realTokenBuyAmount and costInPaymentToken: ",
            (costInPaymentToken * 10 ** 18) / realTokenBuyAmount
        );

        uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(buyer);

        FeeSettings localFeeSettings = FeeSettings(address(token.feeSettings()));

        vm.prank(buyer);
        // vm.expectEmit(true, true, true, true, address(crowdinvesting));
        // emit TokensBought(buyer, tokenBuyAmount, costInPaymentToken);
        paymentToken.transferAndCall(address(crowdinvesting), costInPaymentToken, new bytes(0));

        // log token holdings of buyer
        console.log("buyer token balance: ", token.balanceOf(buyer));
        // log token buy amount
        console.log("tokenBuyAmount: ", tokenBuyAmount);

        assertTrue(paymentToken.balanceOf(buyer) == paymentTokenBalanceBefore - costInPaymentToken, "buyer has paid");
        assertTrue(token.balanceOf(buyer) == realTokenBuyAmount, "buyer has wrong token amount");

        FakeCrowdinvesting fakeCrowdinvesting = new FakeCrowdinvesting(address(token));

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
            token.balanceOf(FeeSettings(address(token.feeSettings())).tokenFeeCollector(address(token))) >=
                localFeeSettings.tokenFee(tokenBuyAmount),
            "fee collector has collected fee in tokens"
        );

        assertTrue(crowdinvesting.tokensSold() == realTokenBuyAmount, "crowdinvesting has sold wrong amount of tokens");
        assertTrue(
            crowdinvesting.tokensBought(buyer) == realTokenBuyAmount,
            "crowdinvesting has stored wrong amount of tokens for buyer"
        );
    }

    function testBuyTooMuch() public {
        uint256 tokenBuyAmount = maxAmountPerBuyer + 1;
        uint256 costInPaymentToken = Math.ceilDiv(tokenBuyAmount * crowdinvesting.getPrice(), 10 ** token.decimals());

        uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        vm.expectRevert("Total amount of bought tokens needs to be lower than or equal to maxAmount");
        paymentToken.transferAndCall(address(crowdinvesting), costInPaymentToken, new bytes(0));
        assertTrue(paymentToken.balanceOf(buyer) == paymentTokenBalanceBefore);
        assertTrue(token.balanceOf(buyer) == 0);
        assertTrue(paymentToken.balanceOf(receiver) == 0);
        assertTrue(crowdinvesting.tokensSold() == 0);
        assertTrue(crowdinvesting.tokensBought(buyer) == 0);
    }

    function testBuyAndMintToDifferentAddress() public {
        address addressWithFunds = address(1);
        address addressForTokens = address(2);

        uint256 currencyAmount = price; // buy one token
        uint256 tokenBuyAmount = (currencyAmount * 10 ** token.decimals()) / crowdinvesting.getPrice();

        vm.prank(buyer);
        paymentToken.transfer(addressWithFunds, currencyAmount);

        vm.prank(addressWithFunds);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);

        // check state before
        assertTrue(paymentToken.balanceOf(addressWithFunds) == currencyAmount, "addressWithFunds has no funds");
        assertTrue(paymentToken.balanceOf(addressForTokens) == 0, "addressForTokens has funds");
        assertTrue(token.balanceOf(addressForTokens) == 0, "addressForTokens has tokens before buy");
        assertTrue(token.balanceOf(addressWithFunds) == 0, "addressWithFunds has tokens before buy");

        // execute buy, with addressForTokens as recipient
        bytes memory data = abi.encode(addressForTokens);

        console.log("bytes lenght: ", data.length);

        vm.startPrank(addressWithFunds);
        paymentToken.transferAndCall(address(crowdinvesting), currencyAmount, data);
        vm.stopPrank();

        // log token holdings of addressForTokens
        console.log("addressForTokens token balance: ", token.balanceOf(addressForTokens));

        // check state after
        console.log("addressWithFunds balance: ", paymentToken.balanceOf(addressWithFunds));
        assertTrue(paymentToken.balanceOf(addressWithFunds) == 0, "addressWithFunds has funds after buy");
        assertTrue(paymentToken.balanceOf(addressForTokens) == 0, "addressForTokens has funds after buy");
        assertTrue(
            token.balanceOf(addressForTokens) == tokenBuyAmount,
            "addressForTokens has wrong amount of tokens after buy"
        );
    }

    function testMultiplePeopleBuyTooMuch() public {
        address person1 = address(1);
        address person2 = address(2);

        uint256 amountToSpend = Math.ceilDiv(
            crowdinvesting.maxAmountOfTokenToBeSold() * crowdinvesting.getPrice(),
            10 ** token.decimals()
        ) / 2;

        vm.prank(buyer);
        paymentToken.transfer(person1, amountToSpend);
        vm.prank(buyer);
        paymentToken.transfer(person2, amountToSpend);

        vm.prank(buyer);
        paymentToken.transferAndCall(address(crowdinvesting), amountToSpend, new bytes(0));
        vm.prank(person1);
        paymentToken.transferAndCall(address(crowdinvesting), amountToSpend, new bytes(0));
        vm.prank(person2);
        vm.expectRevert("Not enough tokens to sell left");
        paymentToken.transferAndCall(address(crowdinvesting), amountToSpend, new bytes(0));
    }

    function testMultipleAddressesBuyForOneReceiver() public {
        address person1 = vm.addr(1);
        address person2 = vm.addr(2);

        uint256 availableBalance = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        paymentToken.transfer(person1, availableBalance / 2);
        vm.prank(buyer);
        paymentToken.transfer(person2, 10 ** 6);

        uint256 amountToPay = Math.ceilDiv(
            (maxAmountPerBuyer / 2) * crowdinvesting.getPrice(),
            10 ** token.decimals()
        ) + 1;
        bytes memory data = abi.encode(buyer);

        console.log("Buying first batch of tokens");

        vm.startPrank(buyer);
        paymentToken.transferAndCall(address(crowdinvesting), amountToPay, data);
        vm.stopPrank();

        console.log("Buying second batch of tokens");

        vm.startPrank(person1);
        vm.expectRevert("Total amount of bought tokens needs to be lower than or equal to maxAmount");
        paymentToken.transferAndCall(address(crowdinvesting), amountToPay, data);
        vm.stopPrank();
    }

    function testCorrectAccounting() public {
        address person1 = address(1);

        uint256 availableBalance = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        paymentToken.transfer(person1, availableBalance / 2);

        uint256 tokenAmount1 = maxAmountOfTokenToBeSold / 2;
        uint256 tokenAmount2 = maxAmountOfTokenToBeSold / 4;

        // check all entries are 0 before
        assertTrue(crowdinvesting.tokensSold() == 0, "crowdinvesting has sold tokens");
        assertTrue(crowdinvesting.tokensBought(buyer) == 0, "buyer has bought tokens");
        assertTrue(crowdinvesting.tokensBought(person1) == 0, "person1 has bought tokens");

        vm.prank(buyer);
        crowdinvesting.buy(tokenAmount1, buyer);
        vm.prank(buyer);
        crowdinvesting.buy(tokenAmount2, person1);

        // check all entries are correct after
        assertTrue(
            crowdinvesting.tokensSold() == tokenAmount1 + tokenAmount2,
            "crowdinvesting has sold wrong amount of tokens"
        );
        assertTrue(crowdinvesting.tokensBought(buyer) == tokenAmount1);
        assertTrue(crowdinvesting.tokensBought(person1) == tokenAmount2);
        assertTrue(token.balanceOf(buyer) == tokenAmount1);
        assertTrue(token.balanceOf(person1) == tokenAmount2);
    }

    function testBuyTooLittle() public {
        uint256 tokenBuyAmount = 5 * 10 ** token.decimals();
        uint256 costInPaymentToken = (tokenBuyAmount * price) / 10 ** 18;

        assert(costInPaymentToken == 35 * 10 ** paymentTokenDecimals); // 35 payment tokens, manually calculated

        uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(buyer);

        uint256 currencyAmount = Math.ceilDiv(
            (minAmountPerBuyer / 2) * crowdinvesting.getPrice(),
            10 ** token.decimals()
        );

        vm.startPrank(buyer);
        vm.expectRevert("Buyer needs to buy at least minAmount");
        paymentToken.transferAndCall(address(crowdinvesting), currencyAmount, new bytes(0));
        assertTrue(paymentToken.balanceOf(buyer) == paymentTokenBalanceBefore);
        assertTrue(token.balanceOf(buyer) == 0);
        assertTrue(paymentToken.balanceOf(receiver) == 0);
        assertTrue(crowdinvesting.tokensSold() == 0);
        assertTrue(crowdinvesting.tokensBought(buyer) == 0);
    }

    function testOnlyCurrencyContractCanCallOnTokenTransfer(address rando) public {
        vm.assume(rando != address(paymentToken));
        vm.prank(rando);
        vm.expectRevert("Only currency contract can call onTokenTransfer");
        crowdinvesting.onTokenTransfer(rando, 0, new bytes(0));
    }
}
