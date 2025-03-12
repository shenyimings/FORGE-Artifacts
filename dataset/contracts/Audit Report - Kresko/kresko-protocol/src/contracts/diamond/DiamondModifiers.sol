// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {Authorization, Role} from "../libs/Authorization.sol";
import {Meta} from "../libs/Meta.sol";
import {Error} from "../libs/Errors.sol";

import {Action} from "../minter/MinterTypes.sol";
import {ms} from "../minter/MinterStorage.sol";

import {ENTERED, NOT_ENTERED} from "../diamond/DiamondTypes.sol";
import {ds} from "../diamond/DiamondStorage.sol";

abstract contract DiamondModifiers {
    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^Authorization: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        Authorization.checkRole(role);
        _;
    }

    /**
     * @notice Ensure only trusted contracts can act on behalf of `_account`
     * @param _accountIsNotMsgSender The address of the collateral asset.
     */
    modifier onlyRoleIf(bool _accountIsNotMsgSender, bytes32 role) {
        if (_accountIsNotMsgSender) {
            Authorization.checkRole(role);
        }
        _;
    }

    modifier onlyOwner() {
        require(Meta.msgSender() == ds().contractOwner, Error.DIAMOND_INVALID_OWNER);
        _;
    }

    modifier onlyPendingOwner() {
        require(Meta.msgSender() == ds().pendingOwner, Error.DIAMOND_INVALID_PENDING_OWNER);
        _;
    }

    modifier nonReentrant() {
        require(ds().entered == NOT_ENTERED, Error.RE_ENTRANCY);
        ds().entered = ENTERED;
        _;
        ds().entered = NOT_ENTERED;
    }
}
