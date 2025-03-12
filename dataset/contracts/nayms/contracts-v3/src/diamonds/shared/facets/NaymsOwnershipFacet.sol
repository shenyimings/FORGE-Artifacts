// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { LibACL } from "src/diamonds/nayms/libs/LibACL.sol";
import { LibHelpers } from "src/diamonds/nayms/libs/LibHelpers.sol";
import { LibConstants } from "src/diamonds/nayms/libs/LibConstants.sol";
import { LibDiamond } from "src/diamonds/shared/libs/LibDiamond.sol";
import { OwnershipFacet } from "src/diamonds/shared/facets/OwnershipFacet.sol";

contract NaymsOwnershipFacet is OwnershipFacet {
    function transferOwnership(address _newOwner) public override {
        super.transferOwnership(_newOwner);

        bytes32 systemID = LibHelpers._stringToBytes32(LibConstants.SYSTEM_IDENTIFIER);
        bytes32 oldAcc1Id = LibHelpers._getIdForAddress(msg.sender);
        bytes32 newAcc1Id = LibHelpers._getIdForAddress(_newOwner);

        LibACL._assignRole(newAcc1Id, systemID, LibHelpers._stringToBytes32(LibConstants.ROLE_SYSTEM_ADMIN));
        require(LibACL._isInGroup(newAcc1Id, systemID, LibHelpers._stringToBytes32(LibConstants.GROUP_SYSTEM_ADMINS)), "NEW owner NOT in sys admin group");

        LibACL._unassignRole(oldAcc1Id, systemID);
        require(!LibACL._isInGroup(oldAcc1Id, systemID, LibHelpers._stringToBytes32(LibConstants.GROUP_SYSTEM_ADMINS)), "OLD owner STILL in sys admin group");
    }
}
