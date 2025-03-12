// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/FakePaymentToken.sol";
import "./resources/CloneCreators.sol";
import "@opengsn/contracts/src/forwarder/Forwarder.sol"; // chose specific version to avoid import error: yarn add @opengsn/contracts@2.2.5

contract TokenERC2612Test is Test {
    using ECDSA for bytes32; // for verify with var.recover()

    AllowList allowList;
    FeeSettings feeSettings;

    Token token;
    Token implementation;
    TokenProxyFactory tokenCloneFactory;
    FakePaymentToken paymentToken;
    //Forwarder trustedForwarder;

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
    uint256 public constant tokenOwnerPrivateKey = 0x3c69254ad72222e3ddf37667b8173dd773bdbdfd93d4af1d192815ff0662de5f;
    address public tokenOwner; // = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;

    address public companyAdmin = 0x38d6703d37988C644D6d31551e9af6dcB762E618;

    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant investor = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;

    address public constant platformHotWallet = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant tokenSpender = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    address public constant platformAdmin = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant feeCollector = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;

    uint32 public constant tokenFeeNumerator = 0;
    uint32 public constant tokenFeeDenominator = 1;
    uint32 public constant crowdinvestingFeeDenominator = 50;
    uint32 public constant privateOfferFeeDenominator = 70;

    uint256 public constant tokenMintAmount = UINT256_MAX - 1; // -1 to avoid overflow caused by fee mint
    bytes32 domainSeparator;
    bytes32 requestType;

    function setUp() public {
        // calculate address
        tokenOwner = vm.addr(tokenOwnerPrivateKey);

        // deploy allow list
        allowList = createAllowList(trustedForwarder, platformAdmin);

        // deploy fee settings
        Fees memory fees = Fees(
            tokenFeeNumerator,
            tokenFeeDenominator,
            1,
            crowdinvestingFeeDenominator,
            1,
            privateOfferFeeDenominator,
            0
        );
        feeSettings = createFeeSettings(
            trustedForwarder,
            platformAdmin,
            fees,
            feeCollector,
            feeCollector,
            feeCollector
        );

        // deploy forwarder
        Forwarder forwarder = new Forwarder();

        implementation = new Token(address(forwarder));
        tokenCloneFactory = new TokenProxyFactory(address(implementation));

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

        // mint tokens for holder
        vm.startPrank(companyAdmin);
        token.increaseMintingAllowance(companyAdmin, tokenMintAmount);
        token.mint(tokenOwner, tokenMintAmount);
        vm.stopPrank();
        assertEq(token.balanceOf(tokenOwner), tokenMintAmount);
    }

    function testPermit(uint256 _tokenPermitAmount, uint256 _tokenTransferAmount) public {
        vm.assume(_tokenPermitAmount < token.balanceOf(tokenOwner));
        vm.assume(_tokenTransferAmount <= _tokenPermitAmount);

        // permit spender to spend holder's tokens
        uint256 nonce = token.nonces(tokenOwner);
        uint256 deadline = block.timestamp + 1000;
        bytes32 permitTypehash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(permitTypehash, tokenOwner, tokenSpender, _tokenPermitAmount, nonce, deadline)
        );

        bytes32 hash = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(tokenOwnerPrivateKey, hash);

        // verify signature
        require(tokenOwner == ECDSA.recover(hash, v, r, s), "invalid signature");

        // check allowance
        assertEq(token.allowance(tokenOwner, tokenSpender), 0);

        // call permit with a wallet that is not tokenOwner
        vm.prank(platformHotWallet);
        token.permit(tokenOwner, tokenSpender, _tokenPermitAmount, deadline, v, r, s);

        // check allowance
        assertEq(token.allowance(tokenOwner, tokenSpender), _tokenPermitAmount);

        // check token balance of investor
        assertEq(token.balanceOf(tokenOwner), tokenMintAmount);
        assertEq(token.balanceOf(investor), 0);

        // spend tokens
        vm.prank(tokenSpender);
        token.transferFrom(tokenOwner, investor, _tokenPermitAmount);

        // check token balance of investor
        assertEq(token.balanceOf(tokenOwner), tokenMintAmount - _tokenPermitAmount);
        assertEq(token.balanceOf(investor), _tokenPermitAmount);
    }
}
