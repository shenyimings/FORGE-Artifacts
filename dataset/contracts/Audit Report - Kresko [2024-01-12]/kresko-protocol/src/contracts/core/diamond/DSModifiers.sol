// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Meta} from "libs/Meta.sol";
import {DSCore} from "diamond/DSCore.sol";
import {Constants} from "common/Constants.sol";
import {ds} from "diamond/DState.sol";

abstract contract DSModifiers {
    modifier initializer(uint256 version) {
        if (ds().initializing != Constants.INITIALIZING) revert DSCore.DIAMOND_NOT_INITIALIZING();
        if (version <= ds().storageVersion) revert DSCore.DIAMOND_ALREADY_INITIALIZED(version, ds().storageVersion);
        _;
    }
    modifier onlyDiamondOwner() {
        if (Meta.msgSender() != ds().contractOwner) {
            revert DSCore.NOT_DIAMOND_OWNER(Meta.msgSender(), ds().contractOwner);
        }
        _;
    }

    modifier onlyPendingDiamondOwner() {
        if (Meta.msgSender() != ds().pendingOwner) {
            revert DSCore.NOT_PENDING_DIAMOND_OWNER(Meta.msgSender(), ds().pendingOwner);
        }
        _;
    }
}
