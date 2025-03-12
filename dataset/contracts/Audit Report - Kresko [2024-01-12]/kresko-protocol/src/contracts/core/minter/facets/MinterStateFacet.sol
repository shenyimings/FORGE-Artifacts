// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ms} from "minter/MState.sol";
import {cs} from "common/State.sol";
import {IMinterStateFacet} from "minter/interfaces/IMinterStateFacet.sol";
import {MinterParams} from "minter/MTypes.sol";
import {collateralAmountToValues, debtAmountToValues} from "common/funcs/Helpers.sol";

/**
 * @author Kresko
 * @title View functions for protocol parameters and asset values
 * @dev As structs do not create views for members, we must expose most of the state values explicitly.
 */
contract MinterStateFacet is IMinterStateFacet {
    /* -------------------------------------------------------------------------- */
    /*                                Configurables                               */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IMinterStateFacet
    function getMinCollateralRatioMinter() external view returns (uint32) {
        return ms().minCollateralRatio;
    }

    /// @inheritdoc IMinterStateFacet
    function getLiquidationThresholdMinter() external view returns (uint32) {
        return ms().liquidationThreshold;
    }

    /// @inheritdoc IMinterStateFacet
    function getMaxLiquidationRatioMinter() external view returns (uint32) {
        return ms().maxLiquidationRatio;
    }

    /// @inheritdoc IMinterStateFacet
    function getParametersMinter() external view returns (MinterParams memory) {
        return MinterParams(ms().minCollateralRatio, ms().liquidationThreshold, ms().maxLiquidationRatio);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Assets                                   */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IMinterStateFacet
    function getKrAssetExists(address _krAsset) external view returns (bool) {
        return cs().assets[_krAsset].isMinterMintable;
    }

    /// @inheritdoc IMinterStateFacet
    function getCollateralExists(address _collateralAsset) external view returns (bool) {
        return cs().assets[_collateralAsset].isMinterCollateral;
    }

    /// @inheritdoc IMinterStateFacet
    function getCollateralValueWithPrice(
        address _collateralAsset,
        uint256 _amount
    ) external view returns (uint256 value, uint256 adjustedValue, uint256 price) {
        return collateralAmountToValues(cs().assets[_collateralAsset], _amount);
    }

    /// @inheritdoc IMinterStateFacet
    function getDebtValueWithPrice(
        address _krAsset,
        uint256 _amount
    ) external view returns (uint256 value, uint256 adjustedValue, uint256 price) {
        return debtAmountToValues(cs().assets[_krAsset], _amount);
    }
}
