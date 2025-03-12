// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { D03ProtocolDefaults, console2, LibAdmin, LibConstants, LibHelpers } from "./defaults/D03ProtocolDefaults.sol";
import { MockAccounts } from "test/utils/users/MockAccounts.sol";
import { Vm } from "forge-std/Vm.sol";

contract T02UserTest is D03ProtocolDefaults, MockAccounts {
    function setUp() public virtual override {
        super.setUp();
    }

    function testGetUserIdFromAddress() public {
        assertEq(nayms.getUserIdFromAddress(account0), LibHelpers._getIdForAddress(account0));
    }

    function testGetAddressFromExternalTokenId() public {
        bytes32 id = LibHelpers._getIdForAddress(LibConstants.DAI_CONSTANT);
        assertEq(nayms.getAddressFromExternalTokenId(id), LibConstants.DAI_CONSTANT);
    }

    function testSetEntityFailsIfNotSysAdmin() public {
        vm.prank(signer2);
        vm.expectRevert("not a system admin");
        nayms.setEntity(account0Id, bytes32(0));
    }

    function testGetSetEntity() public {
        bytes32 entityId = createTestEntity(account0Id);
        nayms.setEntity(signer1Id, entityId);
        assertEq(nayms.getEntity(signer1Id), entityId);
    }

    function testGetBalanceOfTokensForSale() public {
        bytes32 entityId = createTestEntity(account0Id);

        // nothing at first
        assertEq(nayms.getBalanceOfTokensForSale(entityId, entityId), 0);

        // now start token sale to create an offer
        nayms.startTokenSale(entityId, 100, 100);
        assertEq(nayms.getBalanceOfTokensForSale(entityId, entityId), 100);
    }
}
