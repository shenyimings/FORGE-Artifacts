//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../src/libraries/LibAllowlistMasks.sol";
import "./utils/AllowlistHelper.sol";
import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/Allowlist.1.sol";

contract AllowlistV1Sudo is AllowlistV1 {
    function sudoSetAdmin(address admin) external {
        LibAdministrable._setAdmin(admin);
    }
}

abstract contract AllowlistV1TestBase is Test {
    UserFactory internal uf = new UserFactory();

    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    address internal testAdmin = address(0xFA674fDde714fD979DE3EdF0f56aa9716b898eC8);
    address internal allower = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);
    address internal denier = makeAddr("denier");

    AllowlistV1 internal allowlist;

    event SetAllower(address indexed allower);
    event SetDenier(address indexed denier);
    event SetAllowlistPermissions(address[] accounts, uint256[] permissions);
}

contract AllowlistV1InitializationTests is AllowlistV1TestBase {
    function setUp() public {
        allowlist = new AllowlistV1Sudo();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
    }

    function testInitialization() public {
        vm.expectEmit(true, true, true, true);
        emit SetAllower(allower);
        allowlist.initAllowlistV1(testAdmin, allower);

        assertEq(allower, allowlist.getAllower());
        assertEq(testAdmin, allowlist.getAdmin());
    }
}

contract AllowlistV1Tests is AllowlistV1TestBase {
    function setUp() public {
        allowlist = new AllowlistV1Sudo();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(testAdmin, allower);
        allowlist.initAllowlistV1_1(denier);
    }

    uint256 internal constant TEST_ONE_MASK = 0x1;
    uint256 internal constant TEST_TWO_MASK = 0x1 << 1;

    function testSetAllowlistStatus(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(allower);
        assert(allowlist.isAllowed(user, 0x1) == false);
        address[] memory allowees = new address[](1);
        allowees[0] = user;
        uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK);
        vm.expectEmit(true, true, true, true);
        emit SetAllowlistPermissions(allowees, permissions);
        allowlist.setAllowPermissions(allowees, permissions);
        assert(allowlist.isAllowed(user, TEST_ONE_MASK) == true);
    }

    function testSetAllowlistStatus() public {
        address user = uf._new(1);
        vm.startPrank(allower);
        assert(allowlist.isAllowed(user, 0x1) == false);
        address[] memory allowees = new address[](1);
        allowees[0] = user;
        uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK);
        vm.expectEmit(true, true, true, true);
        emit SetAllowlistPermissions(allowees, permissions);
        allowlist.setAllowPermissions(allowees, permissions);
        assert(allowlist.isAllowed(user, TEST_ONE_MASK) == true);
    }

    function testSetAllowlistStatusZeroAddress() public {
        vm.startPrank(allower);
        address[] memory allowees = new address[](1);
        allowees[0] = address(0);
        uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        allowlist.setAllowPermissions(allowees, permissions);
    }

    function testSetAllowlistStatusComplicatedMask(uint256 userOneSalt, uint256 userTwoSalt) public {
        address userOne = uf._new(userOneSalt);
        address userTwo = uf._new(userTwoSalt);
        vm.startPrank(allower);
        assert(allowlist.isAllowed(userOne, TEST_ONE_MASK + TEST_TWO_MASK) == false);
        assert(allowlist.isAllowed(userTwo, TEST_ONE_MASK + TEST_TWO_MASK) == false);
        address[] memory allowees = new address[](2);
        allowees[0] = userOne;
        allowees[1] = userTwo;
        uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK + TEST_TWO_MASK);
        allowlist.setAllowPermissions(allowees, permissions);

        assert(allowlist.isAllowed(userOne, 0x1 + (0x1 << 1)) == true);
        assert(allowlist.isAllowed(userOne, 0x1) == true);
        assert(allowlist.isAllowed(userOne, 0x1 << 1) == true);
        assert(allowlist.isAllowed(userOne, 0x1 << 2) == false);

        assert(allowlist.isAllowed(userTwo, 0x1 + (0x1 << 1)) == true);
        assert(allowlist.isAllowed(userTwo, 0x1) == true);
        assert(allowlist.isAllowed(userTwo, 0x1 << 1) == true);
        assert(allowlist.isAllowed(userTwo, 0x1 << 2) == false);
    }

    function testSetAllowlistStatusUnauthorized(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(user);
        address[] memory allowees = new address[](1);
        allowees[0] = user;
        uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        allowlist.setAllowPermissions(allowees, permissions);
    }

    function testSetDenylistStatusUnauthorized(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(user);
        address[] memory allowees = new address[](1);
        allowees[0] = user;
        uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        allowlist.setDenyPermissions(allowees, permissions);
    }

    function testSetAllowlistStatusMultipleSame(uint256 userOneSalt, uint256 userTwoSalt, uint256 userThreeSalt)
        public
    {
        address userOne = uf._new(userOneSalt);
        address userTwo = uf._new(userTwoSalt);
        address userThree = uf._new(userThreeSalt);
        address[] memory allowees = new address[](3);
        allowees[0] = userOne;
        allowees[1] = userTwo;
        allowees[2] = userThree;
        vm.startPrank(allower);
        assert(allowlist.isAllowed(userOne, TEST_ONE_MASK) == false);
        assert(allowlist.isAllowed(userTwo, TEST_ONE_MASK) == false);
        assert(allowlist.isAllowed(userThree, TEST_ONE_MASK) == false);
        allowlist.setAllowPermissions(allowees, AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK));
        assert(allowlist.isAllowed(userOne, TEST_ONE_MASK) == true);
        assert(allowlist.isAllowed(userTwo, TEST_ONE_MASK) == true);
        assert(allowlist.isAllowed(userThree, TEST_ONE_MASK) == true);
    }

    function testSetAllowlistStatusMultipleDifferent(uint256 userOneSalt, uint256 userTwoSalt, uint256 userThreeSalt)
        public
    {
        address userOne = uf._new(userOneSalt);
        address userTwo = uf._new(userTwoSalt);
        address userThree = uf._new(userThreeSalt);
        address[] memory allowees = new address[](3);
        allowees[0] = userOne;
        allowees[1] = userTwo;
        allowees[2] = userThree;
        uint256[] memory permissions = new uint256[](3);
        permissions[0] = 0;
        permissions[1] = TEST_ONE_MASK;
        permissions[2] = 0;
        vm.startPrank(allower);
        assert(allowlist.isAllowed(userOne, TEST_ONE_MASK) == false);
        assert(allowlist.isAllowed(userTwo, TEST_ONE_MASK) == false);
        assert(allowlist.isAllowed(userThree, TEST_ONE_MASK) == false);
        allowlist.setAllowPermissions(allowees, permissions);
        assert(allowlist.isAllowed(userOne, TEST_ONE_MASK) == false);
        assert(allowlist.isAllowed(userTwo, TEST_ONE_MASK) == true);
        assert(allowlist.isAllowed(userThree, TEST_ONE_MASK) == false);
    }

    function testSetAllowlistRevertForMismatch(uint256 userOneSalt, uint256 userTwoSalt, uint256 userThreeSalt)
        public
    {
        address userOne = uf._new(userOneSalt);
        address userTwo = uf._new(userTwoSalt);
        address userThree = uf._new(userThreeSalt);
        address[] memory allowees = new address[](3);
        allowees[0] = userOne;
        allowees[1] = userTwo;
        allowees[2] = userThree;
        uint256[] memory permissions = new uint256[](2);
        permissions[0] = 0;
        permissions[1] = TEST_ONE_MASK;
        vm.startPrank(allower);
        vm.expectRevert(abi.encodeWithSignature("MismatchedArrayLengths()"));
        allowlist.setAllowPermissions(allowees, permissions);
    }

    function testSetAllower(uint256 adminSalt, uint256 newAllowerSalt) public {
        address admin = uf._new(adminSalt);
        address newAllower = uf._new(newAllowerSalt);
        AllowlistV1Sudo(address(allowlist)).sudoSetAdmin(admin);
        assert(allowlist.getAllower() == allower);
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetAllower(newAllower);
        allowlist.setAllower(newAllower);
        assert(allowlist.getAllower() == newAllower);
    }

    function testSetAllowerUnauthorized(uint256 nonAdminSalt, uint256 newAllowerSalt) public {
        address nonAdmin = uf._new(nonAdminSalt);
        address newAllower = uf._new(newAllowerSalt);
        vm.startPrank(nonAdmin);
        assert(nonAdmin != testAdmin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", nonAdmin));
        allowlist.setAllower(newAllower);
    }

    function testSetDenier(uint256 adminSalt, uint256 newDenierSalt) public {
        address admin = uf._new(adminSalt);
        address newDenier = uf._new(newDenierSalt);
        AllowlistV1Sudo(address(allowlist)).sudoSetAdmin(admin);
        assert(allowlist.getDenier() == denier);
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetDenier(newDenier);
        allowlist.setDenier(newDenier);
        assert(allowlist.getDenier() == newDenier);
    }

    function testSetDenierUnauthorized(uint256 nonAdminSalt, uint256 newDenierSalt) public {
        address nonAdmin = uf._new(nonAdminSalt);
        address newDenier = uf._new(newDenierSalt);
        vm.startPrank(nonAdmin);
        assert(nonAdmin != testAdmin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", nonAdmin));
        allowlist.setDenier(newDenier);
    }

    function testSetUserDenied(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(allower);
        {
            assert(allowlist.isDenied(user) == false);
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions =
                AllowlistHelper.batchAllowees(allowees.length, LibAllowlistMasks.DEPOSIT_MASK);
            allowlist.setAllowPermissions(allowees, permissions);
            assert(allowlist.isDenied(user) == false);
            assert(allowlist.isAllowed(user, LibAllowlistMasks.DEPOSIT_MASK) == true);
        }
        vm.stopPrank();
        vm.startPrank(denier);
        {
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions =
                AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK + LibAllowlistMasks.DENY_MASK);
            allowlist.setDenyPermissions(allowees, permissions);
            assert(allowlist.isDenied(user) == true);
            assert(allowlist.isAllowed(user, LibAllowlistMasks.DEPOSIT_MASK) == false);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", user));
            allowlist.onlyAllowed(user, LibAllowlistMasks.DEPOSIT_MASK);
        }
    }

    function testUnauthorizedPermission(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        allowlist.onlyAllowed(user, LibAllowlistMasks.DEPOSIT_MASK);
    }

    function testGetRawPermissions(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(allower);
        {
            assert(allowlist.isDenied(user) == false);
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK + TEST_TWO_MASK);
            allowlist.setAllowPermissions(allowees, permissions);
            assert(allowlist.isAllowed(user, TEST_ONE_MASK) == true);
            assert(allowlist.hasPermission(user, TEST_ONE_MASK) == true);
            assert(allowlist.isAllowed(user, TEST_TWO_MASK) == true);
            assert(allowlist.hasPermission(user, TEST_TWO_MASK) == true);
            assert(allowlist.getPermissions(user) == TEST_ONE_MASK + TEST_TWO_MASK);
        }
    }

    function testDenyPermissionBeingSetByAllower(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(allower);
        {
            assert(allowlist.isDenied(user) == false);
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, LibAllowlistMasks.DENY_MASK);
            vm.expectRevert(abi.encodeWithSignature("AttemptToSetDenyPermission()"));
            allowlist.setAllowPermissions(allowees, permissions);
        }
    }

    function testUndeny(uint256 userSalt) public {
        address user = uf._new(userSalt);
        address[] memory allowees = new address[](1);
        allowees[0] = user;
        uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK);
        {
            vm.startPrank(allower);
            allowlist.setAllowPermissions(allowees, permissions);
            assert(allowlist.isAllowed(user, TEST_ONE_MASK) == true);
            vm.stopPrank();
        }
        {
            vm.startPrank(denier);
            permissions[0] = LibAllowlistMasks.DENY_MASK;
            // DENY
            allowlist.setDenyPermissions(allowees, permissions);
            assert(allowlist.isDenied(user) == true);
            permissions[0] = 0;
            // UNDENY
            allowlist.setDenyPermissions(allowees, permissions);
            vm.stopPrank();
            assert(allowlist.isAllowed(user, TEST_ONE_MASK) == false);
        }
    }

    function testAllowerCantUndeny(uint256 userSalt) public {
        address user = uf._new(userSalt);
        address[] memory allowees = new address[](1);
        allowees[0] = user;
        uint256[] memory permissions = new uint256[](1);
        // Deny a user
        {
            vm.startPrank(denier);
            permissions[0] = LibAllowlistMasks.DENY_MASK;
            allowlist.setDenyPermissions(allowees, permissions);
            assert(allowlist.isDenied(user) == true);
            vm.stopPrank();
        }
        // Attempt to set a permission on a user through allower
        {
            permissions[0] = TEST_ONE_MASK;
            vm.startPrank(allower);
            vm.expectRevert(abi.encodeWithSignature("AttemptToRemoveDenyPermission()"));
            allowlist.setAllowPermissions(allowees, permissions);
            vm.stopPrank();
        }
    }

    function testRevertsOnIncorrectParameters(uint256 userSalt) public {
        address user = uf._new(userSalt);
        {
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions = new uint256[](0);

            vm.startPrank(allower);
            vm.expectRevert(abi.encodeWithSignature("MismatchedArrayLengths()"));
            allowlist.setAllowPermissions(allowees, permissions);
            vm.stopPrank();

            vm.startPrank(denier);
            vm.expectRevert(abi.encodeWithSignature("MismatchedArrayLengths()"));
            allowlist.setDenyPermissions(allowees, permissions);
            vm.stopPrank();
        }

        {
            address[] memory allowees = new address[](0);
            uint256[] memory permissions = new uint256[](0);

            vm.startPrank(allower);
            vm.expectRevert(abi.encodeWithSignature("InvalidCount()"));
            allowlist.setAllowPermissions(allowees, permissions);
            vm.stopPrank();

            vm.startPrank(denier);
            vm.expectRevert(abi.encodeWithSignature("InvalidCount()"));
            allowlist.setDenyPermissions(allowees, permissions);
            vm.stopPrank();
        }
    }

    function testAllowFail() public {
        vm.startPrank(allower);
        address[] memory allowees = new address[](0);
        uint256[] memory permissions = new uint256[](0);
        vm.expectRevert(abi.encodeWithSignature("InvalidCount()"));
        allowlist.setAllowPermissions(allowees, permissions);
    }

    function testVersion() external {
        assertEq(allowlist.version(), "1.2.1");
    }
}
