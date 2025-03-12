// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {dShare} from "../../src/dShare.sol";
import {TransferRestrictor, ITransferRestrictor} from "../../src/TransferRestrictor.sol";
import {
    IAccessControlDefaultAdminRules,
    IAccessControl
} from "openzeppelin-contracts/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract dShareTest is Test {
    event NameSet(string name);
    event SymbolSet(string symbol);
    event TransferRestrictorSet(ITransferRestrictor indexed transferRestrictor);

    TransferRestrictor restrictor;
    dShare token;
    address restrictor_role = address(1);
    address user = address(2);

    function setUp() public {
        restrictor = new TransferRestrictor(address(this));
        dShare tokenImplementation = new dShare();
        token = dShare(
            address(
                new ERC1967Proxy(
                address(tokenImplementation),
                abi.encodeCall(dShare.initialize, (address(this), "Dinari Token", "dTKN", restrictor))
                )
            )
        );
        restrictor.grantRole(restrictor.RESTRICTOR_ROLE(), restrictor_role);
    }

    function testSetName(string calldata name) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        token.setName(name);

        vm.expectEmit(true, true, true, true);
        emit NameSet(name);
        token.setName(name);
        assertEq(token.name(), name);
    }

    function testSetSymbol(string calldata symbol) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        token.setSymbol(symbol);

        vm.expectEmit(true, true, true, true);
        emit SymbolSet(symbol);
        token.setSymbol(symbol);
        assertEq(token.symbol(), symbol);
    }

    function testSetRestrictor(address account) public {
        vm.assume(account != address(this));

        vm.expectEmit(true, true, true, true);
        emit TransferRestrictorSet(ITransferRestrictor(account));
        token.setTransferRestrictor(ITransferRestrictor(account));
        assertEq(address(token.transferRestrictor()), account);
    }

    function testMint() public {
        token.grantRole(token.MINTER_ROLE(), address(this));
        token.mint(user, 1e18);
        assertEq(token.totalSupply(), 1e18);
        assertEq(token.balanceOf(user), 1e18);
    }

    function testMintUnauthorizedReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE())
        );
        vm.prank(user);
        token.mint(user, 1e18);
    }

    function testBurn() public {
        token.grantRole(token.MINTER_ROLE(), address(this));
        token.mint(user, 1e18);
        token.grantRole(token.BURNER_ROLE(), user);

        vm.prank(user);
        token.burn(0.9e18);
        assertEq(token.totalSupply(), 0.1e18);
        assertEq(token.balanceOf(user), 0.1e18);
    }

    function testAttemptToFalsifyTotalsupply() public {
        token.grantRole(token.MINTER_ROLE(), address(this));
        token.grantRole(token.BURNER_ROLE(), address(2));
        token.mint(user, 1e18);
        token.mint(address(2), 1e18);
        vm.expectRevert(dShare.Unauthorized.selector);
        vm.prank(user);
        token.transfer(address(0), 0.1e18);

        vm.prank(address(2));
        token.burn(0.9e18);
    }

    function testBurnUnauthorizedReverts() public {
        token.grantRole(token.MINTER_ROLE(), address(this));
        token.mint(user, 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, token.BURNER_ROLE())
        );
        vm.prank(user);
        token.burn(0.9e18);
    }

    function testTransferOwnerShip() public {
        // set new address
        address newAdmin = user;
        assertEq(token.hasRole(0, address(this)), true);
        vm.expectRevert(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector);
        token.revokeRole(0, address(this));

        // begin admin transfer
        token.beginDefaultAdminTransfer(newAdmin);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, address(this)
            )
        );
        token.acceptDefaultAdminTransfer();

        vm.startPrank(newAdmin);

        (, uint48 schedule) = token.pendingDefaultAdmin();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, schedule
            )
        );
        token.acceptDefaultAdminTransfer();

        // warp block with 1 seconds
        vm.warp(block.timestamp + 1 seconds);

        // new owner accept admin transfer
        token.acceptDefaultAdminTransfer();

        assertEq(token.hasRole(0, address(this)), false);
        assertEq(token.owner(), newAdmin);
    }

    function testTransfer() public {
        token.grantRole(token.MINTER_ROLE(), address(this));
        token.mint(address(this), 1e18);

        assertTrue(token.transfer(user, 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(user), 1e18);
    }

    function testTransferRestrictedToReverts() public {
        token.grantRole(token.MINTER_ROLE(), address(this));
        token.mint(user, 1e18);
        vm.prank(restrictor_role);
        restrictor.restrict(user);
        assertTrue(token.isBlacklisted(user));

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        token.transfer(user, 1e18);

        token.setTransferRestrictor(ITransferRestrictor(address(0)));
        assertFalse(token.isBlacklisted(user));
    }

    function testTransferRestrictedFromReverts() public {
        token.grantRole(token.MINTER_ROLE(), address(this));
        token.mint(user, 1e18);
        vm.prank(restrictor_role);
        restrictor.restrict(user);
        assertTrue(token.isBlacklisted(user));

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        token.transfer(user, 1e18);

        token.setTransferRestrictor(ITransferRestrictor(address(0)));
        assertFalse(token.isBlacklisted(user));
    }
}
