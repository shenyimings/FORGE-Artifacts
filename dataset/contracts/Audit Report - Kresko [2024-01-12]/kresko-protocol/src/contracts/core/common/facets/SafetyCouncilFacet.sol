// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Errors} from "common/Errors.sol";
import {Role, Enums} from "common/Constants.sol";
import {SafetyState, Pause} from "common/Types.sol";
import {Modifiers} from "common/Modifiers.sol";
import {ISafetyCouncilFacet} from "common/interfaces/ISafetyCouncilFacet.sol";
import {cs} from "common/State.sol";

import {MEvent} from "minter/MEvent.sol";

/* solhint-disable not-rely-on-time */

/**
 * @author Kresko
 * @title SafetyCouncilFacet - protocol safety controls
 * @notice `Role.SAFETY_COUNCIL` must be a multisig.
 */
contract SafetyCouncilFacet is Modifiers, ISafetyCouncilFacet {
    /// @inheritdoc ISafetyCouncilFacet
    function toggleAssetsPaused(
        address[] calldata _assets,
        Enums.Action _action,
        bool _withDuration,
        uint256 _duration
    ) external override onlyRole(Role.SAFETY_COUNCIL) {
        /// @dev loop through `_assets` - be it krAsset or collateral
        for (uint256 i; i < _assets.length; i++) {
            address assetAddr = _assets[i];
            // Revert if asset is invalid
            if (!cs().assets[assetAddr].exists()) revert Errors.ASSET_IS_VOID(Errors.id(assetAddr));

            // Get the safety state
            SafetyState memory safetyState = cs().safetyState[assetAddr][_action];
            // Flip the previous value
            bool willPause = !safetyState.pause.enabled;

            if (willPause) {
                cs().safetyStateSet = true;
            }

            // Update the state for this asset
            cs().safetyState[assetAddr][_action].pause = Pause(
                willPause,
                block.timestamp,
                _withDuration ? block.timestamp + _duration : 0
            );
            // Emit the actions taken
            emit MEvent.SafetyStateChange(_action, MEvent.symbol(assetAddr), assetAddr, willPause ? "paused" : "unpaused");
        }
    }

    /// @inheritdoc ISafetyCouncilFacet
    function setSafetyStateSet(bool val) external override onlyRole(Role.SAFETY_COUNCIL) {
        cs().safetyStateSet = val;
    }

    /// @inheritdoc ISafetyCouncilFacet
    function safetyStateSet() external view override returns (bool) {
        return cs().safetyStateSet;
    }

    /// @inheritdoc ISafetyCouncilFacet
    function safetyStateFor(address _assetAddr, Enums.Action _action) external view override returns (SafetyState memory) {
        return cs().safetyState[_assetAddr][_action];
    }

    /// @inheritdoc ISafetyCouncilFacet
    function assetActionPaused(Enums.Action _action, address _assetAddr) external view returns (bool) {
        return cs().safetyState[_assetAddr][_action].pause.enabled;
    }
}
