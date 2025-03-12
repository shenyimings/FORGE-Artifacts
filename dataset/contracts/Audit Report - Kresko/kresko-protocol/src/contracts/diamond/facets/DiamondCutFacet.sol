// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {IDiamondCutFacet} from "../interfaces/IDiamondCutFacet.sol";
import {DiamondModifiers, Role} from "../DiamondModifiers.sol";
import {initializeDiamondCut} from "../libs/LibDiamondCut.sol";
import {ds} from "../DiamondStorage.sol";

/**
 * @title EIP2535-pattern upgrades.
 * @author Kresko
 * @notice The storage area is in the main proxy diamond storage.
 */
contract DiamondCutFacet is IDiamondCutFacet, DiamondModifiers {
    /// @inheritdoc IDiamondCutFacet
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external onlyRole(Role.ADMIN) {
        ds().diamondCut(_diamondCut, _init, _calldata);
    }

    /// @inheritdoc IDiamondCutFacet
    function upgradeState(address _init, bytes calldata _calldata) external onlyRole(Role.ADMIN) {
        initializeDiamondCut(_init, _calldata);
    }
}
