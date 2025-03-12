// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SmartFarmooorBasicTestHelperAvax.t.sol";
import "../mock/SmartFarmoorUpgradedMock.sol";

contract SmartFarmooorUpgradeTest is SmartFarmooorBasicTestHelperAvax {

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function testSetShouldUpgrade() public {
        uint dummyVersion = 1;
        SmartFarmooorUpgradedMock upgradedSmartFarmooor = new SmartFarmooorUpgradedMock();

        assertTrue(smartFarmooor.hasRole(DEFAULT_ADMIN_ROLE, address(timelock)));
        vm.prank(address(timelock));
        smartFarmooor.upgradeTo(address(upgradedSmartFarmooor));
        SmartFarmooorUpgradedMock(payable(smartFarmooor)).initializev2(dummyVersion);

        //set the implem at mock address
        smartFarmooorImpl = upgradedSmartFarmooor;
        assertEq(SmartFarmooorUpgradedMock(payable(smartFarmooor)).dummyVersion(), dummyVersion);
        verifySmartFarmooor(address(timelock));
    }

    function testRandomCannotUpgrade() public {
        uint dummyVersion = 1;
        SmartFarmooorUpgradedMock upgradedSmartFarmooor = new SmartFarmooorUpgradedMock();

        assertTrue(!smartFarmooor.hasRole(DEFAULT_ADMIN_ROLE, RANDOM_ADDRESS));
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000");
        smartFarmooor.upgradeTo(address(upgradedSmartFarmooor));
    }
}