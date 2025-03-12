// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../../contracts/utils/UpgradeableMultiAdminableBase.sol";

contract MultiAdminableContract is UpgradeableMultiAdminableBase {
    function __MultiAdminableContract_init() public initializer {
        UpgradeableMultiAdminableBase.initialize();
    }

    function crucialMethod() public onlyAdmin {}
}

contract OwnableUpgradeableMultiAdminableTest is Test {
    MultiAdminableContract test;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("bsc"), 27_951_245);

        test = new MultiAdminableContract();
        test.__MultiAdminableContract_init();
    }

    function testFail_callOnlyAdminMethod_nonAdminCase() public {
        test.crucialMethod();
    }

    function testFail_addAdmin_nonOwnerCase() public {
        vm.prank(address(0));
        test.addAdmin(address(this));
    }

    function test_addAdmin() public {
        test.addAdmin(address(this));
        test.crucialMethod();

        vm.expectRevert();
        test.addAdmin(address(this));
    }

    function testFail_removeAdmin_nonOwnerCase() public {
        vm.prank(address(0));
        test.removeAdmin(address(this));
    }

    function test_removeAdmin() public {
        test.addAdmin(address(this));
        test.crucialMethod();

        address admin = address(
            uint160(uint256(keccak256(abi.encodePacked("user address"))))
        );
        test.addAdmin(admin);
        vm.prank(admin);
        test.crucialMethod();

        test.removeAdmin(address(this));
        vm.expectRevert();
        test.crucialMethod();

        test.removeAdmin(admin);
        vm.prank(admin);
        vm.expectRevert();
        test.crucialMethod();
    }
}
