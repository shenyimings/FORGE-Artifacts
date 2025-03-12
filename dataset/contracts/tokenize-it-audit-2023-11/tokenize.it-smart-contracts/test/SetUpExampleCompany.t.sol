// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/factories/CrowdinvestingCloneFactory.sol";
import "./resources/CloneCreators.sol";
import "../contracts/factories/PrivateOfferFactory.sol";
import "./resources/FakePaymentToken.sol";
import "./resources/ERC2771Helper.sol";
import "@opengsn/contracts/src/forwarder/Forwarder.sol"; // chose specific version to avoid import error: yarn add @opengsn/contracts@2.2.5

/**
 * @title Company Setup Example
 * @notice This test is used to demonstrate how to set up a company on the platform. It is not intended to be used as a test, but rather as a reference.
 *          The setUp function will prepare the tokenize.it platform. The test function will then demonstrate how to set up the first of many companys.
 */
contract CompanySetUpTest is Test {
    using ECDSA for bytes32; // for verify with var.recover()

    CrowdinvestingCloneFactory fundraisingFactory;
    Crowdinvesting crowdinvesting;
    AllowList list;
    FeeSettings feeSettings;
    PrivateOfferFactory privateOfferFactory;
    TokenProxyFactory tokenFactory;
    Token token;
    FakePaymentToken paymentToken;
    ERC2771Helper ERC2771helper;

    // copied from openGSN IForwarder
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
        uint256 validUntil;
    }

    // note: this struct is only used to reduce the number of local variables in the test function,
    // because solidity contracts can only have 16 local variables :(
    struct EIP2612Data {
        bytes32 dataStruct;
        bytes32 dataHash;
    }

    // this address will be the admin of contracts controlled by the platform (AllowList, FeeSettings)
    address public constant platformAdmin = 0xDFcEB49eD21aE199b33A76B726E2bea7A72127B0;
    address public constant platformHotWallet = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address public constant platformFeeCollector = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;

    address public constant companyCurrencyReceiver = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;

    address public constant paymentTokenProvider = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;

    // DO NOT USE IN PRODUCTION! Key was generated online for testing only.
    uint256 public constant investorPrivateKey = 0x3c69254ad72222e3ddf37667b8173dd773bdbdfd93d4af1d192815ff0662de5f;
    address public investor; // = 0x38d6703d37988C644D6d31551e9af6dcB762E618;

    address public investorColdWallet = 0x5109709EcFA91a80626ff3989d68f67F5B1dD125;

    // DO NOT USE IN PRODUCTION! Key was generated online for testing only.
    uint256 public constant companyAdminPrivateKey = 0x8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f;
    address public companyAdmin; // = 0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377;

    uint8 public constant paymentTokenDecimals = 6;
    uint256 public constant paymentTokenAmount = 1000 * 10 ** paymentTokenDecimals;

    uint256 public constant price = 7 * 10 ** paymentTokenDecimals; // 7 payment tokens per token

    uint256 public constant maxAmountOfTokenToBeSold = 20 * 10 ** 18; // 20 token
    uint256 public constant maxAmountPerBuyer = maxAmountOfTokenToBeSold / 2; // 10 token
    uint256 public constant minAmountPerBuyer = maxAmountOfTokenToBeSold / 200; // 0.1 token

    uint256 public constant requirements = 0x3842; // 0b111100000010

    uint256 tokenBuyAmount;
    uint256 costInPaymentToken;

    uint32 tokenFeeDenominator = 100;
    uint32 paymentTokenFeeDenominator = 50;

    string name = "ProductiveExampleCompany";
    string symbol = "PEC";

    bytes32 domainSeparator;
    bytes32 requestType;

    // these are global variables to reduce the number of local variables in the test function - solidity contracts can only have 16 local variables :(
    EIP2612Data eip2612Data;
    uint256 deadline;
    bytes32 salt;
    address privateOfferAddress;

    function setUp() public {
        // derive addresses from the private keys. Irl the addresses would be provided by the wallet that holds their private keys.
        investor = vm.addr(investorPrivateKey);
        companyAdmin = vm.addr(companyAdminPrivateKey);

        // set up FeeSettings
        Fees memory fees = Fees(
            1,
            tokenFeeDenominator,
            1,
            paymentTokenFeeDenominator,
            1,
            paymentTokenFeeDenominator,
            0
        );
        feeSettings = createFeeSettings(
            address(8), // fake forwarder
            platformAdmin,
            fees,
            platformFeeCollector,
            platformFeeCollector,
            platformFeeCollector
        );

        // set up AllowList
        list = createAllowList(address(8), platformAdmin);

        // investor registers with the platform
        // after kyc, the platform adds the investor to the allowlist with all the properties they were able to proof
        vm.prank(platformAdmin);
        list.set(investorColdWallet, requirements); // it is possible to set more bits to true than the requirements, but not less, for the investor to be allowed to invest

        // setting up AllowList and FeeSettings is one-time step. These contracts will be used by all companies.

        // set up currency. In real life (irl) this would be a real currency, but for testing purposes we use a fake one.
        vm.prank(paymentTokenProvider);
        paymentToken = new FakePaymentToken(paymentTokenAmount, paymentTokenDecimals); // 1000 tokens with 6 decimals
        vm.prank(paymentTokenProvider);
        paymentToken.transfer(investor, paymentTokenAmount); // transfer currency to investor so they can buy tokens later
        assertTrue(paymentToken.balanceOf(investor) == paymentTokenAmount);
    }

    function deployToken(Forwarder forwarder) public {
        // this should be part of the platform setup, but since the logic contract needs to use the same forwarder as the final token contract, we do it here.
        Token implementation = new Token(address(forwarder));
        tokenFactory = new TokenProxyFactory(address(implementation));

        // set up PrivateOfferFactory. Again, this is done here only because we need the forwarder address.
        Vesting vestingImplementation = new Vesting(address(forwarder));
        VestingCloneFactory vestingCloneFactory = new VestingCloneFactory(address(vestingImplementation));
        privateOfferFactory = new PrivateOfferFactory(vestingCloneFactory);

        // launch the company token. The platform deploys the contract. There is no need to transfer ownership, because the token is never controlled by the address that deployed it.
        // Instead, it is immediately controlled by the address provided in the constructor, which is the companyAdmin in this case.

        vm.startPrank(platformHotWallet);
        token = Token(
            tokenFactory.createTokenProxy(
                0,
                address(forwarder),
                feeSettings,
                companyAdmin,
                list,
                requirements,
                name,
                symbol
            )
        );
        vm.stopPrank();
    }

    /*
        @dev This registration has to be executed only once, because the forwarder does not check if the domain separator and request type 
        match the incoming request. Also, the contents do not matter, because the forwarder does not check them either. We just need the hashes it registers.
    */
    function registerDomainAndRequestType(Forwarder forwarder) public {
        // setting up this helper library will not happen in real life. All functions in this will be written in javascript and executed in the web app.
        // Adding it was necessary to make the meta transactions work in solidity though.
        ERC2771helper = new ERC2771Helper();
        // register a domain separator with the forwarder. The this is a one-time step that will be done by the platform.
        // The domain separator identifies the target contract to the forwarder, which prevents replay attacks (using same signature for other dapps).
        domainSeparator = ERC2771helper.registerDomain(
            forwarder,
            string(abi.encodePacked(address(this))), // just some address
            "v1.0" // contract version
        );

        // register the function with the forwarder. This is also a one-time step that will be done by the platform once for every function that is called via meta transaction.
        requestType = ERC2771helper.registerRequestType(
            forwarder,
            "increaseMintingAllowance",
            "address _minter, uint256 _allowance"
        );
    }

    function launchCompanyAndInvestViaCrowdinvesting(Forwarder forwarder) public {
        // platform deploys the token contract for the founder
        deployToken(forwarder);

        // register domain and request type with the forwarder
        registerDomainAndRequestType(forwarder);

        // just some calculations
        tokenBuyAmount = 5 * 10 ** token.decimals();
        costInPaymentToken = (tokenBuyAmount * price) / 10 ** 18;

        // after setting up their company, the company admin might want to launch a fundraising campaign. They choose all settings in the web, but the contract
        // will be deployed by the platform.
        vm.prank(platformHotWallet);
        fundraisingFactory = new CrowdinvestingCloneFactory(address(new Crowdinvesting(address(forwarder))));

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            companyAdmin,
            companyCurrencyReceiver,
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

        crowdinvesting = Crowdinvesting(fundraisingFactory.createCrowdinvestingClone(0, address(forwarder), arguments));

        // the company admin can now enable the fundraising campaign by granting it a token minting allowance.
        // Because the company admin does not hold eth, they will use a meta transaction to call the function.
        // this requires quite some preparation, on the platform's side

        // build the message the company admin will sign.
        // build request
        bytes memory payload = abi.encodeWithSelector(
            token.increaseMintingAllowance.selector,
            address(crowdinvesting),
            maxAmountOfTokenToBeSold
        );

        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: companyAdmin,
            to: address(token),
            value: 0,
            gas: 1000000,
            nonce: forwarder.getNonce(companyAdmin),
            data: payload,
            validUntil: block.timestamp + 1 hours // like this, the signature will expire after 1 hour. So the platform hotwallet can take some time to execute the transaction.
        });

        // I honestly don't know why we need to do this.
        bytes memory suffixData = "0";

        // pack and hash request
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // sign request. This would usually happen in the web app, which would present the companyAdmin with a request to sign the message. Metamask would come up and present the message to sign.
        // If EIP-712 is used properly, Metamask is able to show some information about the contents of the message, too.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(companyAdminPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        // check the signature is correct
        require(digest.recover(signature) == companyAdmin, "FWD: signature mismatch");

        console.log("signing address: ", request.from);

        // check the crowdinvesting contract has no allowance yet
        assertTrue(token.mintingAllowance(address(crowdinvesting)) == 0);
        // If the platform has received the signature, it can now execute the meta transaction.
        vm.prank(platformHotWallet);
        forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        console.log("Forwarder address: ", address(forwarder));
        console.log("allowance set to: ", token.mintingAllowance(address(crowdinvesting)));

        // check the crowdinvesting contract has a mintingAllowance now now
        assertTrue(token.mintingAllowance(address(crowdinvesting)) == maxAmountOfTokenToBeSold);

        // ----------------------
        // company and fundraising campaign are set up. Now the investor can buy tokens. This requires 2 meta transactions:
        // 1. the investor needs to approve the payment token to be transferred from their account to the fundraising contract using EIP-2612
        // 2. the investor needs to call the buy function of the fundraising contract using EIP-2771
        // ----------------------

        // prepare and execute EIP-2612 approval (ERC-20 permit)

        // https://soliditydeveloper.com/erc20-permit
        eip2612Data.dataStruct = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                investor,
                address(crowdinvesting),
                costInPaymentToken,
                paymentToken.nonces(investor),
                block.timestamp + 1 hours
            )
        );

        eip2612Data.dataHash = keccak256(
            abi.encodePacked(
                uint16(0x1901),
                paymentToken.DOMAIN_SEPARATOR(), //eip2612Data.domainSeparator,
                eip2612Data.dataStruct
            )
        );

        // sign request
        //bytes memory signature
        (v, r, s) = vm.sign(investorPrivateKey, eip2612Data.dataHash);
        require(ecrecover(eip2612Data.dataHash, v, r, s) == investor, "ERC20Permit: invalid _BIG signature");

        // check allowance is 0 before permit
        assertTrue(paymentToken.allowance(investor, address(crowdinvesting)) == 0);

        vm.prank(platformHotWallet);
        paymentToken.permit(investor, address(crowdinvesting), costInPaymentToken, block.timestamp + 1 hours, v, r, s);

        // check allowance is set after permit
        assertTrue(paymentToken.allowance(investor, address(crowdinvesting)) == costInPaymentToken);

        // now buy tokens using EIP-2771
        /*
            create data and signature for execution
        */

        // build request
        payload = abi.encodeWithSelector(crowdinvesting.buy.selector, tokenBuyAmount, investorColdWallet);

        request = IForwarder.ForwardRequest({
            from: investor,
            to: address(crowdinvesting),
            value: 0,
            gas: 1000000,
            nonce: forwarder.getNonce(investor),
            data: payload,
            validUntil: 0
        });

        // pack and hash request
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // sign request
        //bytes memory signature
        (v, r, s) = vm.sign(investorPrivateKey, digest);
        signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        require(digest.recover(signature) == investor, "FWD: signature mismatch");

        // investor has no tokens before
        assertEq(token.balanceOf(investorColdWallet), 0);
        // platformFeeCollector has no tokens or currency before
        assertEq(token.balanceOf(platformFeeCollector), 0);
        assertEq(paymentToken.balanceOf(platformFeeCollector), 0);
        // companyCurrencyReceiver has no currency before
        assertEq(paymentToken.balanceOf(companyCurrencyReceiver), 0);

        // once the platform has received the signature, it can now execute the meta transaction.
        vm.prank(platformHotWallet);
        forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        // investor receives as many tokens as they paid for
        assertTrue(token.balanceOf(investorColdWallet) == tokenBuyAmount, "Investor has no tokens");
        // platformFeeCollector receives the platform fees in token and currency
        assertTrue(token.balanceOf(platformFeeCollector) > 0, "Platform fee in token not received");
        assertTrue(paymentToken.balanceOf(platformFeeCollector) > 0, "Platform fee in currency not received");
        // companyCurrencyReceiver receives the currency
        assertTrue(paymentToken.balanceOf(companyCurrencyReceiver) > 0, "Company currency not received");
    }

    function launchCompanyAndInvestViaPrivateOffer(Forwarder forwarder) public {
        // platform deploys the token contract for the founder
        deployToken(forwarder);

        registerDomainAndRequestType(forwarder);

        // just some calculations
        tokenBuyAmount = 5 * 10 ** token.decimals();
        costInPaymentToken = (tokenBuyAmount * price) / 10 ** 18;
        deadline = block.timestamp + 30 days;

        /*
         After setting up their company, the company founder wants to invite a friend to invest.
         They will use a Private Offer to do so. The process is as follows:
         - The company founder decides on:
            a) the amount of tokens to offer
            b) the price per token
            c) the deadline for the invite
            d) the address that will receive the currency
            e) the currency
         - They also need the address of the friend they want to invite. Knowing the current state of the web app,
            we assume they don't know this address yet. So, using the web app and the values they just decided on, the
            founder creates a private offer link and sends it to the investor.
         - The investor clicks the link and opens the web app. There, they have to do a minimal onboarding, during
            which they sign in with their wallet. Using this address, the web app can now check calculate the personal
            invite smart contract's future address. 
        */

        salt = "random number"; // random number generated and stored by the platform for this Private Offer

        PrivateOfferArguments memory arguments = PrivateOfferArguments(
            investor,
            investorColdWallet,
            companyAdmin,
            tokenBuyAmount,
            price,
            deadline,
            paymentToken,
            token
        );
        privateOfferAddress = privateOfferFactory.predictPrivateOfferAddress(salt, arguments);

        // If the investor wants to invest, they have to sign a meta transaction granting the private offer address an sufficient allowance in paymentToken.
        // Let's prepare this meta transaction using EIP-2612 approval (ERC-20 permit)

        // https://soliditydeveloper.com/erc20-permit
        eip2612Data.dataStruct = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                investor,
                privateOfferAddress,
                costInPaymentToken,
                paymentToken.nonces(investor),
                block.timestamp + 1 hours
            )
        );

        eip2612Data.dataHash = keccak256(
            abi.encodePacked(
                uint16(0x1901),
                paymentToken.DOMAIN_SEPARATOR(), //eip2612Data.domainSeparator,
                eip2612Data.dataStruct
            )
        );

        /* 
            The investor signs the transaction
        */
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(investorPrivateKey, eip2612Data.dataHash);
        require(ecrecover(eip2612Data.dataHash, v, r, s) == investor, "ERC20Permit: invalid _BIG signature");

        /*
            Right here, the investor is done. Everything else is done by the platform and founder. This means the investor can close the web app and go back to their life!

            The platform now has to accept the investors personal data, and, if they are happy with it, add them to the allowList. In our example, we did this already in the setup function.

            In real life, the platform would just store the data and signature and execute the meta transaction once the founder has signed their part, too. But for the sake of simplicity (and because
            solidity is limited in the number of local variables it can have), we will execute the meta transaction right here.
        */

        // check allowance is 0 before permit
        assertTrue(paymentToken.allowance(investor, privateOfferAddress) == 0);

        vm.prank(platformHotWallet);
        paymentToken.permit(investor, privateOfferAddress, costInPaymentToken, block.timestamp + 1 hours, v, r, s);

        // check allowance is set after permit
        assertTrue(paymentToken.allowance(investor, privateOfferAddress) == costInPaymentToken);
        /*

            Next, the founder has to grant a minting allowance to the private offer address. This is done by signing a meta transaction and sending it to the platform.
        */

        // build the message the company admin will sign.
        // build request
        bytes memory payload = abi.encodeWithSelector(
            token.increaseMintingAllowance.selector,
            privateOfferAddress,
            tokenBuyAmount
        );

        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: companyAdmin,
            to: address(token),
            value: 0,
            gas: 1000000,
            nonce: forwarder.getNonce(companyAdmin),
            data: payload,
            validUntil: block.timestamp + 1 hours // like this, the signature will expire after 1 hour. So the platform hotwallet can take some time to execute the transaction.
        });

        // pack and hash request
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(forwarder._getEncoded(request, requestType, "0")) // chose 0 for suffix data
            )
        );

        // sign request. This would usually happen in the web app, which would present the companyAdmin with a request to sign the message. Metamask would come up and present the message to sign.
        // If EIP-712 is used properly, Metamask is able to show some information about the contents of the message, too.
        (v, r, s) = vm.sign(companyAdminPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        // check the signature is correct
        require(digest.recover(signature) == companyAdmin, "FWD: signature mismatch");

        console.log("signing address: ", request.from);

        // check the privateOfferAddress has no allowance yet
        assertTrue(token.mintingAllowance(privateOfferAddress) == 0);
        // If the platform has received the signature, it can now execute the meta transaction.
        vm.prank(platformHotWallet);
        forwarder.execute(
            request,
            domainSeparator,
            requestType,
            "0", // chose 0 for suffix data above
            signature
        );

        // delete some variables
        delete eip2612Data;
        delete request;
        delete digest;
        delete signature;

        console.log("Forwarder address: ", address(forwarder));
        console.log("allowance set to: ", token.mintingAllowance(privateOfferAddress));

        // check the private offer contract address has a mintingAllowance now
        assertTrue(
            token.mintingAllowance(privateOfferAddress) == tokenBuyAmount,
            "Private offer address has wrong minting allowance"
        );

        /* 
            The founder has now granted the private offer address a minting allowance. The investor has granted a payment token allowance to the private offer address.
            This means we can deploy the private offer contract and be done with it!
        */

        // investor has no tokens before
        assertEq(token.balanceOf(investorColdWallet), 0);
        // platformFeeCollector has no tokens or currency before
        assertEq(token.balanceOf(platformFeeCollector), 0);
        assertEq(paymentToken.balanceOf(platformFeeCollector), 0);
        // companyCurrencyReceiver has no currency before
        assertEq(paymentToken.balanceOf(companyCurrencyReceiver), 0);

        vm.prank(platformHotWallet);
        privateOfferFactory.deployPrivateOffer(salt, arguments);

        // investor receives as many tokens as they paid for
        assertTrue(token.balanceOf(investorColdWallet) == tokenBuyAmount, "Investor has no tokens");
        // platformFeeCollector receives the platform fees in token and currency
        assertTrue(token.balanceOf(platformFeeCollector) > 0, "Platform fee in token not received");
        assertTrue(paymentToken.balanceOf(platformFeeCollector) > 0, "Platform fee in currency not received");
        // companyCurrencyReceiver receives the currency
        assertTrue(paymentToken.balanceOf(companyAdmin) > 0, "Company currency not received");
    }

    function testlaunchCompanyAndInvestViaCrowdinvestingWithLocalForwarder() public {
        launchCompanyAndInvestViaCrowdinvesting(new Forwarder());
    }

    function testlaunchCompanyAndInvestViaCrowdinvestingWithMainnetGSNForwarder() public {
        // uses deployed forwarder on mainnet with fork. https://docs-v2.opengsn.org/networks/ethereum/mainnet.html
        launchCompanyAndInvestViaCrowdinvesting(Forwarder(payable(0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA)));
    }

    function testlaunchCompanyAndInvestViaPrivateOfferWithLocalForwarder() public {
        launchCompanyAndInvestViaPrivateOffer(new Forwarder());
    }

    function testlaunchCompanyAndInvestViaPrivateOfferWithMainnetGSNForwarder() public {
        // uses deployed forwarder on mainnet with fork. https://docs-v2.opengsn.org/networks/ethereum/mainnet.html
        launchCompanyAndInvestViaPrivateOffer(Forwarder(payable(0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA)));
    }
}
