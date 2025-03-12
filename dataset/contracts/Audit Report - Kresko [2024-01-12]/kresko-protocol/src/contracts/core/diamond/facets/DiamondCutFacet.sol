// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Role} from "common/Constants.sol";
import {Modifiers} from "common/Modifiers.sol";

import {IDiamondCutFacet, IExtendedDiamondCutFacet} from "diamond/interfaces/IDiamondCutFacet.sol";
import {FacetCut, Initializer} from "diamond/DSTypes.sol";
import {DSModifiers} from "diamond/DSModifiers.sol";
import {DSCore} from "diamond/DSCore.sol";

/**
 * @title EIP2535-pattern upgrades.
 * @author Nick Mudge
 * @author Kresko
 * @notice Reference implementation of diamondCut. Extended to allow executing initializers without cuts.
 */
contract DiamondCutFacet is IDiamondCutFacet, IExtendedDiamondCutFacet, DSModifiers, Modifiers {
    /// @inheritdoc IDiamondCutFacet
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _initializer,
        bytes calldata _calldata
    ) external onlyRole(Role.DEFAULT_ADMIN) {
        DSCore.cut(_diamondCut, _initializer, _calldata);
    }

    /// @inheritdoc IExtendedDiamondCutFacet
    function executeInitializer(address _initializer, bytes calldata _calldata) external onlyRole(Role.DEFAULT_ADMIN) {
        DSCore.exec(_initializer, _calldata);
    }

    /// @inheritdoc IExtendedDiamondCutFacet
    function executeInitializers(Initializer[] calldata _initializers) external onlyRole(Role.DEFAULT_ADMIN) {
        for (uint256 i; i < _initializers.length; ) {
            DSCore.exec(_initializers[i].initContract, _initializers[i].initData);
            unchecked {
                i++;
            }
        }
    }
}
