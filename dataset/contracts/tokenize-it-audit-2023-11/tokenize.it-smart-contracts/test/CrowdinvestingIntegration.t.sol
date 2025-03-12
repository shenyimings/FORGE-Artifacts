// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/factories/CrowdinvestingCloneFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/FakePaymentToken.sol";
import "./resources/MaliciousPaymentToken.sol";
import "./resources/CloneCreators.sol";

contract CrowdinvestingTest is Test {
    Crowdinvesting crowdinvesting;
    AllowList list;
    FeeSettings feeSettings;

    Token implementation = new Token(trustedForwarder);
    TokenProxyFactory tokenFactory = new TokenProxyFactory(address(implementation));
    Token token;
    FakePaymentToken paymentToken;
    CrowdinvestingCloneFactory fundraisingFactory;

    address public constant platformAdmin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant investor = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant minter = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant companyOwner = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
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
        list = createAllowList(trustedForwarder, platformAdmin);
        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 100);
        feeSettings = createFeeSettings(
            trustedForwarder,
            platformAdmin,
            fees,
            platformAdmin,
            platformAdmin,
            platformAdmin
        );
        vm.prank(platformAdmin);
        token = Token(
            tokenFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                companyOwner,
                list,
                0x0,
                "TESTTOKEN",
                "TEST"
            )
        );

        // set up currency
        vm.prank(paymentTokenProvider);
        paymentToken = new FakePaymentToken(paymentTokenAmount, paymentTokenDecimals); // 1000 tokens with 6 decimals
        // transfer currency to buyer
        vm.prank(paymentTokenProvider);
        paymentToken.transfer(investor, paymentTokenAmount);
        assertTrue(paymentToken.balanceOf(investor) == paymentTokenAmount);

        vm.prank(companyOwner);

        fundraisingFactory = new CrowdinvestingCloneFactory(address(new Crowdinvesting(trustedForwarder)));

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

        crowdinvesting = Crowdinvesting(fundraisingFactory.createCrowdinvestingClone(0, trustedForwarder, arguments));

        // allow crowdinvesting contract to mint
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(companyOwner);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(address(crowdinvesting), maxAmountOfTokenToBeSold);

        // give crowdinvesting contract allowance
        vm.prank(investor);
        paymentToken.approve(address(crowdinvesting), paymentTokenAmount);
    }

    /*
    set up with FakePaymentToken which has variable decimals to make sure that doesn't break anything
    */
    function feeCalculation(uint32 tokenFeeDenominator, uint32 crowdinvestingFeeDenominator) public {
        // apply fees for test
        Fees memory fees = Fees(
            1,
            tokenFeeDenominator,
            1,
            crowdinvestingFeeDenominator,
            1,
            crowdinvestingFeeDenominator,
            uint64(block.timestamp + 13 weeks)
        );
        vm.prank(platformAdmin);
        feeSettings.planFeeChange(fees);
        vm.warp(fees.validityDate + 1 seconds);
        vm.prank(platformAdmin);
        feeSettings.executeFeeChange();

        uint8 _paymentTokenDecimals = 6;
        // uint8 _maxDecimals = 25;
        // for (
        //     uint8 _paymentTokenDecimals = 1;
        //     _paymentTokenDecimals < _maxDecimals;
        //     _paymentTokenDecimals++
        // ) {
        //uint8 _paymentTokenDecimals = 10;

        /*
        _paymentToken: 1 FPT = 10**_paymentTokenDecimals FPTbits (bit = smallest subunit of token)
        Token: 1 CT = 10**18 CTbits
        price definition: 30FPT buy 1CT, but must be expressed in FPTbits/CT
        price = 30 * 10**_paymentTokenDecimals
        */
        uint256 _price = 30 * 10 ** _paymentTokenDecimals;
        uint256 _maxMintAmount = 2 ** 256 - 1; // need maximum possible value because we are using a fake token with variable decimals
        uint256 _paymentTokenAmount = 1000 * 10 ** _paymentTokenDecimals;

        list = createAllowList(trustedForwarder, platformAdmin);
        Token _token = Token(
            tokenFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                companyOwner,
                list,
                0x0,
                "FEETESTTOKEN",
                "TEST"
            )
        );

        vm.prank(paymentTokenProvider);
        paymentToken = new FakePaymentToken(_paymentTokenAmount, _paymentTokenDecimals);
        vm.prank(companyOwner);

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            address(this),
            payable(receiver),
            1,
            _maxMintAmount / 100,
            _price,
            _price,
            _price,
            _maxMintAmount,
            paymentToken,
            _token,
            0,
            address(0)
        );

        Crowdinvesting _crowdinvesting = Crowdinvesting(
            fundraisingFactory.createCrowdinvestingClone(0, trustedForwarder, arguments)
        );

        // allow invite contract to mint
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(companyOwner);
        _token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        _token.increaseMintingAllowance(address(_crowdinvesting), _maxMintAmount);

        // mint _paymentToken for buyer
        vm.prank(paymentTokenProvider);
        paymentToken.transfer(investor, _paymentTokenAmount);
        assertTrue(paymentToken.balanceOf(investor) == _paymentTokenAmount);

        // give invite contract allowance
        vm.prank(investor);
        paymentToken.approve(address(_crowdinvesting), _paymentTokenAmount);

        // run actual test

        uint tokenAmount = 33 * 10 ** token.decimals();

        // buyer has 1k FPT
        assertTrue(paymentToken.balanceOf(investor) == _paymentTokenAmount);
        // they should be able to buy 33 CT for 999 FPT
        vm.prank(investor);
        _crowdinvesting.buy(tokenAmount, investor);
        // buyer should have 10 FPT left
        assertTrue(paymentToken.balanceOf(investor) == 10 * 10 ** _paymentTokenDecimals);
        // buyer should have the 33 CT they bought
        assertTrue(_token.balanceOf(investor) == tokenAmount, "buyer has wrong amount of token");
        // receiver should have the 990 FPT that were paid, minus the fee

        uint currencyAmount = 990 * 10 ** _paymentTokenDecimals;
        uint256 currencyFee = currencyAmount /
            FeeSettings(address(token.feeSettings())).defaultCrowdinvestingFeeDenominator();
        assertTrue(
            paymentToken.balanceOf(receiver) == currencyAmount - currencyFee,
            "receiver has wrong amount of currency"
        );
        // fee collector should have the token and currency fees
        assertEq(
            currencyFee,
            paymentToken.balanceOf(feeSettings.feeCollector()),
            "fee collector has wrong amount of currency"
        );
        assertEq(
            tokenAmount / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator(),
            _token.balanceOf(feeSettings.feeCollector()),
            "fee collector has wrong amount of token"
        );
        // }
    }

    function testFee0() public {
        feeCalculation(type(uint32).max, type(uint32).max);
    }

    function testVariousFees(uint32 tokenFeeDenominator, uint32 crowdinvestingFeeDenominator) public {
        vm.assume(tokenFeeDenominator >= 20);
        vm.assume(crowdinvestingFeeDenominator >= 20);
        feeCalculation(tokenFeeDenominator, crowdinvestingFeeDenominator);
    }

    /*
    set up with FakePaymentToken which has variable decimals to make sure that doesn't break anything
    */
    function testVaryDecimals() public {
        uint8 _maxDecimals = 25;
        //FakePaymentToken paymentToken;

        for (uint8 _paymentTokenDecimals = 1; _paymentTokenDecimals < _maxDecimals; _paymentTokenDecimals++) {
            //uint8 _paymentTokenDecimals = 10;

            /*
            _paymentToken: 1 FPT = 10**_paymentTokenDecimals FPTbits (bit = smallest subunit of token)
            Token: 1 CT = 10**18 CTbits
            price definition: 30FPT buy 1CT, but must be expressed in FPTbits/CT
            price = 30 * 10**_paymentTokenDecimals
            */
            uint256 _price = 30 * 10 ** _paymentTokenDecimals;
            uint256 _maxMintAmount = 2 ** 256 - 1; // need maximum possible value because we are using a fake token with variable decimals
            uint256 _paymentTokenAmount = 1000 * 10 ** _paymentTokenDecimals;

            list = createAllowList(trustedForwarder, platformAdmin);
            Token _token = Token(
                tokenFactory.createTokenProxy(
                    0,
                    trustedForwarder,
                    feeSettings,
                    companyOwner,
                    list,
                    0x0,
                    "DECIMALSTESTTOKEN",
                    "TEST"
                )
            );

            vm.prank(paymentTokenProvider);
            paymentToken = new FakePaymentToken(_paymentTokenAmount, _paymentTokenDecimals);
            vm.prank(companyOwner);

            CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
                address(this),
                payable(receiver),
                1,
                _maxMintAmount / 100,
                _price,
                _price,
                _price,
                _maxMintAmount,
                paymentToken,
                _token,
                0,
                address(0)
            );

            Crowdinvesting _crowdinvesting = Crowdinvesting(
                fundraisingFactory.createCrowdinvestingClone(0, trustedForwarder, arguments)
            );
            // allow invite contract to mint
            bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

            vm.prank(companyOwner);
            _token.grantRole(roleMintAllower, mintAllower);
            vm.prank(mintAllower);
            _token.increaseMintingAllowance(address(_crowdinvesting), _maxMintAmount);

            // mint _paymentToken for buyer
            vm.prank(paymentTokenProvider);
            paymentToken.transfer(investor, _paymentTokenAmount);
            assertTrue(paymentToken.balanceOf(investor) == _paymentTokenAmount);

            // give invite contract allowance
            vm.prank(investor);
            paymentToken.approve(address(_crowdinvesting), _paymentTokenAmount);

            // run actual test

            uint tokenAmount = 33 * 10 ** token.decimals();

            // buyer has 1k FPT
            assertTrue(paymentToken.balanceOf(investor) == _paymentTokenAmount);
            // they should be able to buy 33 CT for 999 FPT
            vm.prank(investor);
            _crowdinvesting.buy(tokenAmount, investor);
            // buyer should have 10 FPT left
            assertTrue(paymentToken.balanceOf(investor) == 10 * 10 ** _paymentTokenDecimals);
            // buyer should have the 33 CT they bought
            assertTrue(_token.balanceOf(investor) == tokenAmount, "buyer has wrong amount of token");
            // receiver should have the 990 FPT that were paid, minus the fee
            uint currencyAmount = 990 * 10 ** _paymentTokenDecimals;
            uint256 currencyFee = currencyAmount /
                FeeSettings(address(token.feeSettings())).defaultCrowdinvestingFeeDenominator();
            assertTrue(
                paymentToken.balanceOf(receiver) == currencyAmount - currencyFee,
                "receiver has wrong amount of currency"
            );
            // fee collector should have the token and currency fees
            assertEq(
                currencyFee,
                paymentToken.balanceOf(feeSettings.feeCollector()),
                "fee collector has wrong amount of currency"
            );
            assertEq(
                tokenAmount / FeeSettings(address(token.feeSettings())).defaultTokenFeeDenominator(),
                _token.balanceOf(feeSettings.feeCollector()),
                "fee collector has wrong amount of token"
            );
        }
    }
}
