// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/FakePaymentToken.sol";
import "./resources/ERC2771Helper.sol";
import "./resources/CloneCreators.sol";
import "@opengsn/contracts/src/forwarder/Forwarder.sol"; // chose specific version to avoid import error: yarn add @opengsn/contracts@2.2.5

contract TokenERC2771Test is Test {
    using ECDSA for bytes32; // for verify with var.recover()

    AllowList allowList;
    FeeSettings feeSettings;

    Token token;
    FakePaymentToken paymentToken;
    //Forwarder trustedForwarder;
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

    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    // DO NOT USE IN PRODUCTION! Key was generated online for testing only.
    uint256 public constant companyAdminPrivateKey = 0x3c69254ad72222e3ddf37667b8173dd773bdbdfd93d4af1d192815ff0662de5f;
    address public companyAdmin; // = 0x38d6703d37988C644D6d31551e9af6dcB762E618;

    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant investor = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;

    address public constant receiver = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant platformHotWallet = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant sender = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    address public constant platformAdmin = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant feeCollector = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;

    uint32 public constant tokenFeeDenominator = 100;
    uint32 public constant crowdinvestingFeeDenominator = 50;
    uint32 public constant privateOfferFeeDenominator = 70;

    bytes32 domainSeparator;
    bytes32 requestType;

    function setUp() public {
        // calculate address
        companyAdmin = vm.addr(companyAdminPrivateKey);

        // deploy allow list
        allowList = createAllowList(trustedForwarder, platformAdmin);

        // deploy fee settings
        Fees memory fees = Fees(
            1,
            tokenFeeDenominator,
            1,
            crowdinvestingFeeDenominator,
            1,
            privateOfferFeeDenominator,
            0
        );
        vm.prank(platformAdmin);
        feeSettings = createFeeSettings(
            trustedForwarder,
            address(this),
            fees,
            feeCollector,
            feeCollector,
            feeCollector
        );

        // deploy helper functions (only for testing with foundry)
        ERC2771helper = new ERC2771Helper();
    }

    function setUpTokenWithForwarder(Forwarder forwarder) public {
        // this is part of the platform setup, but we need it here to use the correct forwarder
        Token implementation = new Token(address(forwarder));
        TokenProxyFactory tokenCloneFactory = new TokenProxyFactory(address(implementation));

        // deploy company token
        token = Token(
            tokenCloneFactory.createTokenProxy(
                0,
                address(forwarder),
                feeSettings,
                companyAdmin,
                allowList,
                0x0,
                "TESTTOKEN",
                "TEST"
            )
        );

        // register domainSeparator with forwarder
        domainSeparator = ERC2771helper.registerDomain(
            forwarder,
            Strings.toHexString(uint256(uint160(address(token))), 20),
            "1"
        );

        // register request type with forwarder
        requestType = ERC2771helper.registerRequestType(forwarder, "mint", "address _to,uint256 _amount");
    }

    function testMintWithLocalForwarder(uint256 _tokenMintAmount) public {
        mintWithERC2771(new Forwarder(), _tokenMintAmount);
    }

    function testMintWithMainnetGSNForwarder(uint256 _tokenMintAmount) public {
        // uses deployed forwarder on mainnet with fork. https://docs-v2.opengsn.org/networks/ethereum/mainnet.html
        mintWithERC2771(Forwarder(payable(0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA)), _tokenMintAmount);
    }

    function mintWithERC2771(Forwarder _forwarder, uint256 _tokenMintAmount) public {
        vm.assume(_tokenMintAmount < UINT256_MAX - feeSettings.tokenFee(_tokenMintAmount));

        setUpTokenWithForwarder(_forwarder);

        // /*
        //  * increase minting allowance
        //  */
        // //vm.prank(companyAdmin);
        // //token.increaseMintingAllowance(companyAdmin, tokenMintAmount);

        // // 1. build request
        // bytes memory payload = abi.encodeWithSelector(
        //     token.increaseMintingAllowance.selector,
        //     companyAdmin,
        //     _tokenMintAmount
        // );

        // IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
        //     from: companyAdmin,
        //     to: address(token),
        //     value: 0,
        //     gas: 1000000,
        //     nonce: _forwarder.getNonce(companyAdmin),
        //     data: payload,
        //     validUntil: 0
        // });

        // bytes memory suffixData = "0";

        // // 2. pack and hash request
        // bytes32 digest = keccak256(
        //     abi.encodePacked(
        //         "\x19\x01",
        //         domainSeparator,
        //         keccak256(_forwarder._getEncoded(request, requestType, suffixData))
        //     )
        // );

        // // 3. sign request
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(companyAdminPrivateKey, digest);
        // bytes memory signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        // require(digest.recover(signature) == request.from, "FWD: signature mismatch");

        // assertEq(token.mintingAllowance(companyAdmin), 0, "Minting allowance is not 0");

        // // 4.  execute request
        // vm.prank(platformHotWallet);
        // _forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        // assertEq(token.mintingAllowance(companyAdmin), _tokenMintAmount, "Minting allowance is not tokenMintAmount");

        /*
         * mint tokens
         */

        // 1. build request
        bytes memory payload = abi.encodeWithSelector(token.mint.selector, investor, _tokenMintAmount);

        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: companyAdmin,
            to: address(token),
            value: 0,
            gas: 1000000,
            nonce: _forwarder.getNonce(companyAdmin),
            data: payload,
            validUntil: 0
        });

        // 2. pack and hash request
        bytes memory suffixData = "0";
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(_forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // 3. sign request
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(companyAdminPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        require(digest.recover(signature) == request.from, "FWD: signature mismatch");

        // 4.  execute request
        assertEq(token.balanceOf(investor), 0, "Investor has tokens before mint");
        assertEq(token.balanceOf(feeCollector), 0, "FeeCollector has tokens before mint");

        // send call through forwarder contract
        vm.prank(platformHotWallet);
        _forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        assertEq(token.balanceOf(investor), _tokenMintAmount, "Investor received wrong token amount");
        assertEq(
            token.balanceOf(feeCollector),
            feeSettings.tokenFee(_tokenMintAmount),
            "FeeCollector received wrong token amount"
        );

        /*
            try to execute request again (must fail)
        */
        vm.expectRevert("FWD: nonce mismatch");
        _forwarder.execute(request, domainSeparator, requestType, suffixData, signature);
    }

    function testUpdateSettingsWithLocalForwarder(uint256 _newRequirements) public {
        updateSettingsWithERC2771(new Forwarder(), _newRequirements);
    }

    function testUpdateSettingsWithMainnetGSNForwarder(uint256 _newRequirements) public {
        // uses deployed forwarder on mainnet with fork. https://docs-v2.opengsn.org/networks/ethereum/mainnet.html
        updateSettingsWithERC2771(Forwarder(payable(0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA)), _newRequirements);
    }

    function updateSettingsWithERC2771(Forwarder _forwarder, uint256 _newRequirements) public {
        setUpTokenWithForwarder(_forwarder);

        /*
         * set new requirements
         */

        // 1. build request
        bytes memory payload = abi.encodeWithSelector(token.setRequirements.selector, _newRequirements);

        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: companyAdmin,
            to: address(token),
            value: 0,
            gas: 1000000,
            nonce: _forwarder.getNonce(companyAdmin),
            data: payload,
            validUntil: 0
        });

        bytes memory suffixData = "0";

        // 2. pack and hash request
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(_forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // 3. sign request
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(companyAdminPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        require(digest.recover(signature) == request.from, "FWD: signature mismatch");

        assertEq(token.requirements(), 0, "Requirements allowance are not 0");

        // 4.  execute request
        vm.prank(platformHotWallet);
        _forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        assertEq(token.requirements(), _newRequirements, "Requirements allowance are not _newRequirements");

        /*
         * pause token
         */

        // 1. build request
        payload = abi.encodeWithSelector(token.pause.selector);

        request = IForwarder.ForwardRequest({
            from: companyAdmin,
            to: address(token),
            value: 0,
            gas: 1000000,
            nonce: _forwarder.getNonce(companyAdmin),
            data: payload,
            validUntil: 0
        });

        // 2. pack and hash request
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(_forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // 3. sign request
        (v, r, s) = vm.sign(companyAdminPrivateKey, digest);
        signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        require(digest.recover(signature) == request.from, "FWD: signature mismatch");

        // 4.  execute request
        assertEq(token.paused(), false, "Token is already paused");

        // send call through forwarder contract
        vm.prank(platformHotWallet);
        _forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        assertEq(token.paused(), true, "Token is not paused");

        /*
            try to execute request again (must fail)
        */
        vm.expectRevert("FWD: nonce mismatch");
        _forwarder.execute(request, domainSeparator, requestType, suffixData, signature);
    }
}
