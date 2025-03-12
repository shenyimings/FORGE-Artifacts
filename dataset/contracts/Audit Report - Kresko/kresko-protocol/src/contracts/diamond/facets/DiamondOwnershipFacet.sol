// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {IDiamondOwnershipFacet} from "../interfaces/IDiamondOwnershipFacet.sol";
import {DiamondModifiers} from "../DiamondModifiers.sol";
import {ds} from "../DiamondStorage.sol";

contract DiamondOwnershipFacet is IDiamondOwnershipFacet, DiamondModifiers {
    /* -------------------------------------------------------------------------- */
    /*                                    Write                                   */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IDiamondOwnershipFacet
    function transferOwnership(address _newOwner) external override onlyOwner {
        ds().initiateOwnershipTransfer(_newOwner);
    }

    /// @inheritdoc IDiamondOwnershipFacet
    function acceptOwnership() external override onlyPendingOwner {
        ds().finalizeOwnershipTransfer();
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Read                                    */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IDiamondOwnershipFacet
    function owner() external view override returns (address owner_) {
        return ds().contractOwner;
    }

    /// @inheritdoc IDiamondOwnershipFacet
    function pendingOwner() external view override returns (address pendingOwner_) {
        return ds().pendingOwner;
    }

    /// @inheritdoc IDiamondOwnershipFacet
    function initialized() external view returns (bool initialized_) {
        return ds().initialized;
    }
}
