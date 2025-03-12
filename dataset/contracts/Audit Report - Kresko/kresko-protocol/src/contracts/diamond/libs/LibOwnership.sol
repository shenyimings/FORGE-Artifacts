// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {IERC165} from "../../shared/IERC165.sol";
import {IDiamondCutFacet} from "../interfaces/IDiamondCutFacet.sol";
import {IDiamondLoupeFacet} from "../interfaces/IDiamondLoupeFacet.sol";
import {IDiamondOwnershipFacet} from "../interfaces/IDiamondOwnershipFacet.sol";
import {IAuthorizationFacet} from "../interfaces/IAuthorizationFacet.sol";

import {GeneralEvent, AuthEvent} from "../../libs/Events.sol";
import {Error} from "../../libs/Errors.sol";
import {Meta} from "../../libs/Meta.sol";

import {NOT_ENTERED} from "../DiamondTypes.sol";
import {DiamondState} from "../DiamondState.sol";

library LibOwnership {
    /* -------------------------------------------------------------------------- */
    /*                         Initialization & Ownership                         */
    /* -------------------------------------------------------------------------- */

    /// @notice Ownership initializer
    /// @notice Only called on the first deployment
    function initialize(DiamondState storage self, address _owner) internal {
        require(!self.initialized, Error.ALREADY_INITIALIZED);
        self.entered = NOT_ENTERED;
        self.initialized = true;
        self.storageVersion++;
        self.contractOwner = _owner;

        self.supportedInterfaces[type(IDiamondLoupeFacet).interfaceId] = true;
        self.supportedInterfaces[type(IERC165).interfaceId] = true;
        self.supportedInterfaces[type(IDiamondCutFacet).interfaceId] = true;
        self.supportedInterfaces[type(IDiamondOwnershipFacet).interfaceId] = true;
        self.supportedInterfaces[type(IAuthorizationFacet).interfaceId] = true;

        emit GeneralEvent.Deployed(_owner, self.storageVersion);
        emit AuthEvent.OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Initiate ownership transfer to a new address
     * @param _newOwner address that is set as the pending new owner
     * @notice caller must be the current contract owner
     */
    function initiateOwnershipTransfer(DiamondState storage self, address _newOwner) internal {
        require(Meta.msgSender() == self.contractOwner, Error.DIAMOND_INVALID_OWNER);
        require(_newOwner != address(0), "DS: Owner cannot be 0-address");

        self.pendingOwner = _newOwner;

        emit AuthEvent.PendingOwnershipTransfer(self.contractOwner, _newOwner);
    }

    /**
     * @dev Transfer the ownership to the new pending owner
     * @notice caller must be the pending owner
     */
    function finalizeOwnershipTransfer(DiamondState storage self) internal {
        address sender = Meta.msgSender();
        require(sender == self.pendingOwner, Error.DIAMOND_INVALID_PENDING_OWNER);
        self.contractOwner = self.pendingOwner;
        self.pendingOwner = address(0);

        emit AuthEvent.OwnershipTransferred(self.contractOwner, sender);
    }
}
