// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/Token.sol";
import "../contracts/factories/FeeSettingsCloneFactory.sol";
import "../contracts/factories/CrowdinvestingCloneFactory.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/factories/PrivateOfferFactory.sol";
import "./resources/FakePaymentToken.sol";
import "./resources/CloneCreators.sol";

contract FeeSettingsIntegrationTest is Test {
    FeeSettings feeSettings;
    Fees customFees;
    Token token;
    FakePaymentToken currency;
    PrivateOfferFactory privateOfferFactory;
    CrowdinvestingCloneFactory crowdinvestingCloneFactory;

    uint256 MAX_INT = type(uint256).max;

    address public constant platformAdmin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant investor = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant companyAdmin = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant paymentTokenAdmin = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant owner = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant receiver = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant paymentTokenProvider = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    uint256 public constant price = 3e18;

    uint256 public constant tokenAmount = 1000e18;
    uint256 public constant currencyAmount = 3000e18;

    address public constant exampleTokenAddress = address(74);

    function setUp() public {
        FeeSettings feeSettingsLogic = new FeeSettings(trustedForwarder);
        FeeSettingsCloneFactory feeSettingsCloneFactory = new FeeSettingsCloneFactory(address(feeSettingsLogic));
        customFees = Fees(2, 1000, 3, 1000, 5, 1000, 101 * 365 days);
        Fees memory fees = Fees(1, 101, 2, 102, 3, 103, 0);
        vm.prank(platformAdmin);
        feeSettings = FeeSettings(
            feeSettingsCloneFactory.createFeeSettingsClone(
                "salt",
                trustedForwarder,
                platformAdmin,
                fees,
                platformAdmin,
                platformAdmin,
                platformAdmin
            )
        );

        AllowList allowList = createAllowList(trustedForwarder, owner);

        Token tokenLogic = new Token(trustedForwarder);
        TokenProxyFactory tokenProxyFactory = new TokenProxyFactory(address(tokenLogic));
        token = Token(
            tokenProxyFactory.createTokenProxy(
                "salt",
                trustedForwarder,
                feeSettings,
                companyAdmin,
                allowList,
                0,
                "Test Token",
                "TST"
            )
        );

        Crowdinvesting crowdinvestingLogic = new Crowdinvesting(trustedForwarder);
        crowdinvestingCloneFactory = new CrowdinvestingCloneFactory(address(crowdinvestingLogic));

        // using a fake vesting clone factory here because we don't need this functionality for this test
        privateOfferFactory = new PrivateOfferFactory(VestingCloneFactory(address(294)));

        vm.startPrank(paymentTokenProvider);
        currency = new FakePaymentToken(currencyAmount, 18);
        currency.transfer(investor, currencyAmount);
        vm.stopPrank();
    }

    function testMintUsesCustomFeeAndCollector(address _customFeeCollector) public {
        vm.assume(_customFeeCollector != address(0));
        vm.assume(_customFeeCollector != platformAdmin);

        vm.warp(100 * 365 days);

        assertEq(token.balanceOf(investor), 0, "token.balanceOf(investor) != 0 before");
        assertEq(token.balanceOf(_customFeeCollector), 0, "token.balanceOf(customFeeCollector) != 0 before");

        vm.startPrank(platformAdmin);
        feeSettings.setCustomFee(address(token), customFees);
        feeSettings.setCustomTokenFeeCollector(address(token), _customFeeCollector);
        vm.stopPrank();
        vm.prank(companyAdmin);
        token.mint(investor, tokenAmount);

        assertEq(token.balanceOf(investor), tokenAmount, "token.balanceOf(investor) != 100e18 after");
        assertEq(
            token.balanceOf(_customFeeCollector),
            (tokenAmount * 2) / 1000,
            "token.balanceOf(customFeeCollector) != 3e18 after"
        );
    }

    function testPrivateOfferUsesCustomFeeAndCollector(address _customFeeCollector) public {
        vm.assume(_customFeeCollector != address(0));
        vm.assume(_customFeeCollector != platformAdmin);

        vm.warp(100 * 365 days);

        vm.startPrank(platformAdmin);
        feeSettings.setCustomFee(address(token), customFees);
        feeSettings.setCustomPrivateOfferFeeCollector(address(token), _customFeeCollector);
        vm.stopPrank();

        assertEq(token.balanceOf(investor), 0, "token.balanceOf(investor) != 0 before");
        assertEq(currency.balanceOf(_customFeeCollector), 0, "currency.balanceOf(customFeeCollector) != 0 before");

        // get private offer address
        address expectedPrivateOfferAddress = privateOfferFactory.predictPrivateOfferAddress(
            "salt",
            PrivateOfferArguments(
                investor,
                investor,
                companyAdmin,
                tokenAmount,
                price,
                block.timestamp + 1000,
                currency,
                token
            )
        );

        // grant allowances
        vm.prank(companyAdmin);
        token.increaseMintingAllowance(expectedPrivateOfferAddress, tokenAmount);

        vm.prank(investor);
        currency.increaseAllowance(expectedPrivateOfferAddress, currencyAmount);

        // create private offer
        privateOfferFactory.deployPrivateOffer(
            "salt",
            PrivateOfferArguments(
                investor,
                investor,
                companyAdmin,
                tokenAmount,
                price,
                block.timestamp + 1000,
                currency,
                token
            )
        );

        // check balances
        console.log("token.balanceOf(investor)", token.balanceOf(investor));
        assertEq(token.balanceOf(investor), tokenAmount, "token.balanceOf(investor) != 1000e18 after");
        console.log("token.balanceOf(platformAdmin)", token.balanceOf(platformAdmin));
        // hint: token fees are paid to platform admin because we do not set a custom token fee receiver
        assertEq(
            token.balanceOf(platformAdmin),
            (tokenAmount * 2) / 1000,
            "token.balanceOf(customFeeCollector) != 2e18 after"
        );

        console.log("currency.balanceOf(investor)", currency.balanceOf(investor));
        assertEq(currency.balanceOf(investor), 0, "currency.balanceOf(investor) != 0 after");
        console.log("currency.balanceOf(_customFeeCollector)", currency.balanceOf(_customFeeCollector));
        assertEq(
            currency.balanceOf(_customFeeCollector),
            (currencyAmount * 5) / 1000,
            "currency.balanceOf(customFeeCollector) wrong after"
        );
    }

    function testCrowdinvestingUsesCustomFeeAndCollector(address _customFeeCollector) public {
        vm.assume(_customFeeCollector != address(0));
        vm.assume(_customFeeCollector != platformAdmin);

        vm.warp(100 * 365 days);

        vm.startPrank(platformAdmin);
        feeSettings.setCustomFee(address(token), customFees);
        feeSettings.setCustomCrowdinvestingFeeCollector(address(token), _customFeeCollector);
        vm.stopPrank();

        assertEq(token.balanceOf(investor), 0, "token.balanceOf(investor) != 0 before");
        assertEq(currency.balanceOf(_customFeeCollector), 0, "token.balanceOf(customFeeCollector) != 0 before");

        // set up crowdinvesting
        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            companyAdmin,
            companyAdmin,
            0,
            type(uint256).max,
            price,
            price,
            price,
            type(uint256).max,
            IERC20(address(currency)),
            token,
            101 * 365 days,
            address(0)
        );

        Crowdinvesting crowdinvesting = Crowdinvesting(
            crowdinvestingCloneFactory.createCrowdinvestingClone("salt", trustedForwarder, arguments)
        );

        // grant allowances
        vm.prank(companyAdmin);
        token.increaseMintingAllowance(address(crowdinvesting), tokenAmount);

        vm.prank(investor);
        currency.increaseAllowance(address(crowdinvesting), currencyAmount);

        // buy
        vm.prank(investor);
        crowdinvesting.buy(tokenAmount, investor);

        // check balances
        console.log("token.balanceOf(investor)", token.balanceOf(investor));
        assertEq(token.balanceOf(investor), tokenAmount, "token.balanceOf(investor) != 1000e18 after");
        console.log("token.balanceOf(platformAdmin)", token.balanceOf(platformAdmin));
        // hint: token fees are paid to platform admin because we do not set a custom token fee receiver
        assertEq(
            token.balanceOf(platformAdmin),
            (tokenAmount * 2) / 1000,
            "token.balanceOf(customFeeCollector) != 2e18 after"
        );

        console.log("currency.balanceOf(investor)", currency.balanceOf(investor));
        assertEq(currency.balanceOf(investor), 0, "currency.balanceOf(investor) != 0 after");
        console.log("currency.balanceOf(_customFeeCollector)", currency.balanceOf(_customFeeCollector));
        assertEq(
            currency.balanceOf(_customFeeCollector),
            (currencyAmount * 3) / 1000,
            "currency.balanceOf(customFeeCollector) wrong after"
        );
    }
}
