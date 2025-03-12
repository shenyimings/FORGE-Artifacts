// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/CloneCreators.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

contract tokenTest is Test {
    Token token;
    AllowList allowList;
    FeeSettings feeSettings;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;
    address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant snapshotCreator = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant minter = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant burner = 0x4109709eCFa91A80626ff3989d68F67f5b1DD124;
    address public constant transfererAdmin = 0x5109709EcFA91a80626ff3989d68f67F5B1dD125;
    address public constant transferer = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant pauser = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant feeSettingsAndAllowListOwner = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;

    event RequirementsChanged(uint256 newRequirements);

    function setUp() public {
        allowList = createAllowList(trustedForwarder, feeSettingsAndAllowListOwner);
        Fees memory fees = Fees(0, 1, 0, 1, 0, 1, 0);
        feeSettings = createFeeSettings(
            trustedForwarder,
            feeSettingsAndAllowListOwner,
            fees,
            feeSettingsAndAllowListOwner,
            feeSettingsAndAllowListOwner,
            feeSettingsAndAllowListOwner
        );

        address tokenHolder = address(this);

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
                0,
                "testToken",
                "TEST"
            )
        );

        // set up roles
        vm.startPrank(admin);
        token.grantRole(token.MINTALLOWER_ROLE(), mintAllower);
        token.increaseMintingAllowance(minter, 200);
        token.grantRole(token.SNAPSHOTCREATOR_ROLE(), snapshotCreator);
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

    function testOneSnapshot() public {
        uint256 totalSupply = token.totalSupply();
        vm.prank(admin);
        uint256 snapshotId = token.createSnapshot();
        assertEq(snapshotId, 1, "snapshotId is wrong");

        assertTrue(token.totalSupplyAt(snapshotId) == totalSupply, "totalSupplyAt is wrong");

        vm.prank(pauser);
        token.transfer(transferer, 100);

        // balances must have changed
        assertTrue(token.balanceOf(pauser) == 0, "pauser balance is wrong");
        assertTrue(token.balanceOf(transferer) == 100, "transferer balance is wrong");

        // but snapshot balances must not have changed
        assertTrue(token.balanceOfAt(pauser, snapshotId) == 100, "pauser balanceAt is wrong");
        assertTrue(token.balanceOfAt(transferer, snapshotId) == 0, "transferer balanceAt is wrong");
    }

    function testMultipleSnapshots(uint256 amount1, address rando1, uint256 amount2, address rando2) public {
        vm.assume(rando1 != rando2);
        vm.assume(amount2 < (type(uint256).max) - 1000);
        vm.assume(amount1 < (type(uint256).max - amount2) - 1000);
        vm.assume(rando1 != address(0));
        vm.assume(rando2 != address(0));
        vm.assume(rando1 != trustedForwarder);
        vm.assume(rando2 != trustedForwarder);
        vm.assume(token.balanceOf(rando1) == 0);
        vm.assume(token.balanceOf(rando2) == 0);

        uint256 snapshotId;

        vm.prank(snapshotCreator);
        snapshotId = token.createSnapshot();
        console.log("snapshotId: %s", snapshotId);

        vm.prank(mintAllower);
        token.mint(rando1, amount1);

        vm.prank(snapshotCreator);
        token.createSnapshot();

        vm.prank(mintAllower);
        token.mint(rando2, amount2);

        vm.prank(snapshotCreator);
        token.createSnapshot();

        vm.prank(rando1);
        token.transfer(rando2, amount1);

        vm.prank(snapshotCreator);
        token.createSnapshot();

        // verify all snapshots are correct
        assertTrue(token.balanceOfAt(rando1, 1) == 0, "rando1 balanceAt 0 is wrong");
        assertTrue(token.balanceOfAt(rando1, 2) == amount1, "rando1 balanceAt is wrong");
        assertTrue(token.balanceOfAt(rando1, 3) == amount1, "rando1 balanceAt is wrong");
        assertTrue(token.balanceOfAt(rando1, 4) == 0, "rando1 balanceAt is wrong");

        assertTrue(token.balanceOfAt(rando2, 1) == 0, "rando2 balanceAt is wrong");
        assertTrue(token.balanceOfAt(rando2, 2) == 0, "rando2 balanceAt is wrong");
        assertTrue(token.balanceOfAt(rando2, 3) == amount2, "rando2 balanceAt is wrong");
        assertTrue(token.balanceOfAt(rando2, 4) == amount1 + amount2, "rando2 balanceAt is wrong");

        // verify current balances are correct
        assertTrue(token.balanceOf(rando1) == 0, "rando1 balance is wrong");
        assertTrue(token.balanceOf(rando2) == amount1 + amount2, "rando2 balance is wrong");
    }

    function testOnlySnapshotCreatorCanSnapshot(address rando) public {
        vm.assume(rando != address(0));
        vm.assume(!token.hasRole(token.SNAPSHOTCREATOR_ROLE(), rando));
        string memory randoString = Strings.toHexString(uint256(uint160(rando)), 20);
        console.log("randoString: %s", randoString);
        string memory error = string.concat("AccessControl: account ", randoString);
        console.log("error: %s", error);
        error = string.concat(
            error,
            " is missing role 0x0f808695ed46dfe84975e0868729f72470bdaab0e6414a139300622caf1a5940"
        );
        console.log("error: %s", error);
        vm.prank(rando);
        vm.expectRevert(bytes(error));
        token.createSnapshot();

        // make rando snapshot creator and create snapshot
        vm.startPrank(admin);
        token.grantRole(token.SNAPSHOTCREATOR_ROLE(), rando);
        vm.stopPrank();
        vm.prank(rando);
        token.createSnapshot();
    }

    function testAdminIsRoleAdminForSnapshotCreator(address rando) public {
        vm.assume(rando != address(0));
        vm.assume(!token.hasRole(token.SNAPSHOTCREATOR_ROLE(), rando));

        // make rando snapshot creator and create snapshot
        bytes32 snapshotCreatorRole = token.SNAPSHOTCREATOR_ROLE();
        vm.prank(admin);
        token.grantRole(snapshotCreatorRole, rando);
        require(token.hasRole(token.SNAPSHOTCREATOR_ROLE(), rando), "rando is not snapshot creator");
    }
}
