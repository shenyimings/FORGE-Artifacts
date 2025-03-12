// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/AllowListCloneFactory.sol";

contract AllowListCloneFactoryTest is Test {
    AllowListCloneFactory factory;
    AllowList oracle;

    address public constant companyAdmin = address(1);
    address public trustedForwarder = address(2);

    function setUp() public {
        // set up price oracle factory
        AllowList allowListLogicContract = new AllowList(trustedForwarder);
        factory = new AllowListCloneFactory(address(allowListLogicContract));
    }

    function testAddressPrediction(bytes32 _rawSalt, address _owner) public {
        vm.assume(_owner != address(0));

        bytes32 salt = keccak256(abi.encodePacked(_rawSalt, trustedForwarder, _owner));

        address expected1 = factory.predictCloneAddress(salt);
        address expected2 = factory.predictCloneAddress(_rawSalt, trustedForwarder, _owner);
        assertEq(expected1, expected2, "address prediction with salt and params not equal");

        address actual = factory.createAllowListClone(_rawSalt, trustedForwarder, _owner);
        assertEq(expected1, actual, "address prediction failed");
    }

    function testWrongForwarderFails(address _wrongTrustedForwarder) public {
        vm.assume(_wrongTrustedForwarder != trustedForwarder);
        vm.assume(_wrongTrustedForwarder != address(0));

        // using a different trustedForwarder should fail
        vm.expectRevert("AllowListCloneFactory: Unexpected trustedForwarder");
        factory.createAllowListClone(bytes32(uint256(0)), _wrongTrustedForwarder, companyAdmin);

        // using the correct trustedForwarder should succeed
        factory.createAllowListClone(bytes32(uint256(2)), trustedForwarder, companyAdmin);
    }

    function testOwnerInit(address _owner) public {
        vm.assume(_owner != address(0));

        // using a different owner should fail
        vm.expectRevert("owner can not be zero address");
        factory.createAllowListClone(bytes32(uint256(0)), trustedForwarder, address(0));

        // using the correct owner should succeed
        AllowList list = AllowList(factory.createAllowListClone(bytes32(uint256(0)), trustedForwarder, _owner));

        assertEq(list.owner(), _owner, "owner wrong");
    }

    function testOwnerChangesAddress(address _owner) public {
        address rando = address(3);
        vm.assume(_owner != address(0));
        vm.assume(_owner != rando);

        AllowList list = AllowList(factory.createAllowListClone(bytes32(uint256(0)), trustedForwarder, _owner));

        assertEq(list.owner(), _owner, "owner wrong");

        AllowList list2 = AllowList(factory.createAllowListClone(bytes32(uint256(0)), trustedForwarder, rando));

        assertTrue(address(list) != address(list2), "clones should have different addresses");
    }

    // test second deployment fails
    function testSecondDeploymentFails(address _owner) public {
        vm.assume(_owner != address(0));

        factory.createAllowListClone(bytes32(uint256(0)), trustedForwarder, _owner);

        vm.expectRevert("ERC1167: create2 failed");
        factory.createAllowListClone(bytes32(uint256(0)), trustedForwarder, _owner);
    }
}
