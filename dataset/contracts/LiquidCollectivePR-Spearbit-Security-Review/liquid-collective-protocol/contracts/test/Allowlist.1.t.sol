//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

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

contract AllowlistV1Tests is Test {
    UserFactory internal uf = new UserFactory();

    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    address internal testAdmin = address(0xFA674fDde714fD979DE3EdF0f56aa9716b898eC8);
    address internal allower = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);

    AllowlistV1 internal allowlist;

    event SetAllower(address indexed allower);
    event SetAllowlistPermissions(address[] accounts, uint256[] permissions);

    function setUp() public {
        allowlist = new AllowlistV1Sudo();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(testAdmin, allower);
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
        allowlist.allow(allowees, permissions);
        assert(allowlist.isAllowed(user, TEST_ONE_MASK) == true);
    }

    function testSetAllowlistStatusZeroAddress() public {
        vm.startPrank(allower);
        address[] memory allowees = new address[](1);
        allowees[0] = address(0);
        uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        allowlist.allow(allowees, permissions);
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
        allowlist.allow(allowees, permissions);

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
        allowlist.allow(allowees, permissions);
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
        allowlist.allow(allowees, AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK));
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
        allowlist.allow(allowees, permissions);
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
        vm.expectRevert(abi.encodeWithSignature("MismatchedAlloweeAndStatusCount()"));
        allowlist.allow(allowees, permissions);
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

    function testSetUserDenied(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(allower);
        {
            assert(allowlist.isDenied(user) == false);
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK);
            allowlist.allow(allowees, permissions);
            assert(allowlist.isDenied(user) == false);
            assert(allowlist.isAllowed(user, TEST_ONE_MASK) == true);
        }
        {
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions =
                AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK + LibAllowlistMasks.DENY_MASK);
            allowlist.allow(allowees, permissions);
            assert(allowlist.isDenied(user) == true);
            assert(allowlist.isAllowed(user, TEST_ONE_MASK) == false);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", user));
            allowlist.onlyAllowed(user, TEST_ONE_MASK);
        }
    }

    function testGetRawPermissions(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(allower);
        {
            assert(allowlist.isDenied(user) == false);
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions = AllowlistHelper.batchAllowees(allowees.length, TEST_ONE_MASK + TEST_TWO_MASK);
            allowlist.allow(allowees, permissions);
            assert(allowlist.isAllowed(user, TEST_ONE_MASK) == true);
            assert(allowlist.hasPermission(user, TEST_ONE_MASK) == true);
            assert(allowlist.isAllowed(user, TEST_TWO_MASK) == true);
            assert(allowlist.hasPermission(user, TEST_TWO_MASK) == true);
            assert(allowlist.getPermissions(user) == TEST_ONE_MASK + TEST_TWO_MASK);
        }
        {
            address[] memory allowees = new address[](1);
            allowees[0] = user;
            uint256[] memory permissions = AllowlistHelper.batchAllowees(
                allowees.length, TEST_ONE_MASK + TEST_TWO_MASK + LibAllowlistMasks.DENY_MASK
            );
            allowlist.allow(allowees, permissions);
            assert(allowlist.isAllowed(user, TEST_ONE_MASK) == false);
            assert(allowlist.hasPermission(user, TEST_ONE_MASK) == true);
            assert(allowlist.isAllowed(user, TEST_TWO_MASK) == false);
            assert(allowlist.hasPermission(user, TEST_TWO_MASK) == true);
            assert(allowlist.getPermissions(user) == TEST_ONE_MASK + TEST_TWO_MASK + LibAllowlistMasks.DENY_MASK);
        }
    }
}
