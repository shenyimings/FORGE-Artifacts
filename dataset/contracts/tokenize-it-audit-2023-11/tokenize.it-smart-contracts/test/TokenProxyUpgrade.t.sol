// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/ERC2771Helper.sol";
import "./resources/CloneCreators.sol";

contract TokenV2 is Token {
    constructor(address _trustedForwarder) Token(_trustedForwarder) {}

    function initializeV2() public reinitializer(2) {
        version = 2;
    }

    function makeMeRich() public {
        _mint(_msgSender(), 1e50);
    }
}

contract tokenProxyUpgradeTest is Test {
    using ECDSA for bytes32;

    Token implementation;
    AllowList allowList;
    FeeSettings feeSettings;
    TokenProxyFactory factory;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;
    address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant requirer = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant minter = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant burner = 0x4109709eCFa91A80626ff3989d68F67f5b1DD124;
    address public constant transfererAdmin = 0x5109709EcFA91a80626ff3989d68f67F5B1dD125;
    address public constant transferer = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant pauser = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant feeSettingsAndAllowListOwner = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;

    uint256 requirements = 0;

    function setUp() public {
        allowList = createAllowList(trustedForwarder, feeSettingsAndAllowListOwner);
        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 0);
        feeSettings = createFeeSettings(
            trustedForwarder,
            feeSettingsAndAllowListOwner,
            fees,
            feeSettingsAndAllowListOwner,
            feeSettingsAndAllowListOwner,
            feeSettingsAndAllowListOwner
        );
        vm.stopPrank();

        implementation = new Token(trustedForwarder);

        factory = new TokenProxyFactory(address(implementation));
    }

    function testUpgrade(string memory someName, address anotherTrustedForwarder) public {
        vm.assume(anotherTrustedForwarder != address(0));
        bytes memory someNameBytes = bytes(someName);
        console.log(someNameBytes.length);
        vm.assume(someNameBytes.length != 0);

        address companyAdmin = address(4);

        Token token = Token(
            factory.createTokenProxy(0, trustedForwarder, feeSettings, companyAdmin, allowList, 0, someName, "TOK")
        );

        assertEq(token.version(), 1);
        assertEq(token.name(), someName);

        TokenV2 implementationV2 = new TokenV2(anotherTrustedForwarder);
        vm.prank(companyAdmin);
        token.upgradeTo(address(implementationV2));

        TokenV2 tokenV2 = TokenV2(address(token));

        // test new function in V2 is available now
        assertEq(token.balanceOf(address(this)), 0);
        tokenV2.makeMeRich();
        assertEq(token.balanceOf(address(this)), 1e50);

        // v2 is not initialized yet, so version should still be 1
        assertEq(token.version(), 1);

        // initialize v2
        tokenV2.initializeV2();
        assertEq(token.version(), 2);

        // initializing again is not possible
        vm.expectRevert("Initializable: contract is already initialized");
        tokenV2.initializeV2();
    }
}
