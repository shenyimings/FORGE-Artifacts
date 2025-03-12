// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "./resources/CloneCreators.sol";

contract tokenTest is Test {
    Token token;
    AllowList allowList;
    FeeSettings feeSettings;
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

    uint256 requirements = 934332;

    event RequirementsChanged(uint256 newRequirements);

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

        address tokenHolder = address(this);

        vm.startPrank(feeSettingsAndAllowListOwner);
        allowList.set(pauser, requirements);
        allowList.set(transferer, requirements);
        allowList.set(tokenHolder, requirements);
        allowList.set(admin, requirements);

        vm.stopPrank();

        Token implementation = new Token(trustedForwarder);
        TokenProxyFactory tokenCloneFactory = new TokenProxyFactory(address(implementation));

        token = Token(
            tokenCloneFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                admin,
                allowList,
                requirements,
                "testToken",
                "TEST"
            )
        );
        console.log(msg.sender);

        // set up roles
        vm.startPrank(admin);
        token.grantRole(token.MINTALLOWER_ROLE(), mintAllower);
        token.increaseMintingAllowance(minter, 200);
        vm.stopPrank();

        vm.prank(minter);
        token.mint(tokenHolder, 100);
        vm.prank(minter);
        token.mint(pauser, 100);
        vm.prank(pauser);
        token.approve(admin, 100); // for transferFrom test case

        assertTrue(token.balanceOf(tokenHolder) == 100, "tokenHolder balance is wrong");
        assertTrue(token.balanceOf(pauser) == 100, "pauser balance is wrong");
    }

    function testSimpleTransfer() public {
        vm.prank(pauser);
        token.transfer(transferer, 100);
    }

    function test10Transfers() public {
        vm.startPrank(pauser);
        token.transfer(transferer, 10);
        token.transfer(transferer, 12);
        token.transfer(transferer, 13);
        token.transfer(transferer, 14);
        token.transfer(transferer, 15);
        vm.stopPrank();

        vm.startPrank(transferer);
        token.transfer(pauser, 10);
        token.transfer(pauser, 12);
        token.transfer(pauser, 13);
        token.transfer(pauser, 14);
        token.transfer(pauser, 15);
        vm.stopPrank();
    }

    function testGrantAllowance() public {
        vm.prank(pauser);
        token.approve(transferer, 100);
    }

    function testSimpleTransferFrom() public {
        vm.prank(admin);
        token.transferFrom(pauser, admin, 100);
    }

    function testFailTransfer() public {
        vm.prank(pauser);
        token.transfer(burner, 100);
        //assertTrue(token.balanceOf(burner) == 0, "burner balance is wrong");
    }
}
