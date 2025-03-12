// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./interfaces/ISpoolOwner.sol";
import "./external/@openzeppelin/access/Ownable.sol";

/**
 * @notice Implementation of the {ISpoolOwner} interface.
 *
 * @dev
 * This implementation acts as a simple central Spool owner oracle.
 * All Spool contracts should refer to this contract to check the owner of the Spool.
 */
contract SpoolOwner is ISpoolOwner, Ownable {
    /* ========== VIEWS ========== */

    /**
    * @notice checks if input is the spool owner contract.
    * 
    * @param user the address to check
    * 
    * @return isOwner returns true if user is the Spool owner, else returns false.
    */
    function isSpoolOwner(address user) external view override returns(bool isOwner) {
        if (user == owner()) {
            isOwner = true;
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
    * @notice removed renounceOwnership function
    * 
    * @dev 
    * overrides OpenZeppelin renounceOwnership() function and reverts in all cases,
    * as Spool ownership should never be renounced.
    */
    function renounceOwnership() public view override onlyOwner {
        revert("SpoolOwner::renounceOwnership: Cannot renounce Spool ownership");
    }
}
