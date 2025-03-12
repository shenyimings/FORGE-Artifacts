// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IStateFacet} from "../interfaces/IStateFacet.sol";

import {MinterParams, KrAsset, CollateralAsset} from "../MinterTypes.sol";
import {MinterState, ms} from "../MinterStorage.sol";

/**
 * @author Kresko
 * @title View functions for protocol parameters and asset values
 * @dev As structs do not create views for members, we must expose most of the state values explicitly.
 */
contract StateFacet is IStateFacet {
    /// @inheritdoc IStateFacet
    function domainSeparator() external view returns (bytes32) {
        return ms().domainSeparator;
    }

    /// @inheritdoc IStateFacet
    function minterInitializations() external view returns (uint256) {
        return ms().initializations;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Configurables                               */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IStateFacet
    function feeRecipient() external view returns (address) {
        return ms().feeRecipient;
    }

    /// @inheritdoc IStateFacet
    function ammOracle() external view returns (address) {
        return ms().ammOracle;
    }

    /// @inheritdoc IStateFacet
    function extOracleDecimals() external view returns (uint8) {
        return ms().extOracleDecimals;
    }

    /// @inheritdoc IStateFacet
    function minimumCollateralizationRatio() external view returns (uint256) {
        return ms().minimumCollateralizationRatio;
    }

    /// @inheritdoc IStateFacet
    function liquidationIncentiveMultiplier() external view returns (uint256) {
        return ms().liquidationIncentiveMultiplier;
    }

    /// @inheritdoc IStateFacet
    function minimumDebtValue() external view returns (uint256) {
        return ms().minimumDebtValue;
    }

    /// @inheritdoc IStateFacet
    function liquidationThreshold() external view returns (uint256) {
        return ms().liquidationThreshold;
    }

    /// @inheritdoc IStateFacet
    function maxLiquidationMultiplier() external view returns (uint256) {
        return ms().maxLiquidationMultiplier;
    }

    /// @inheritdoc IStateFacet
    function oracleDeviationPct() external view returns (uint256) {
        return ms().oracleDeviationPct;
    }

    /// @inheritdoc IStateFacet
    function getAllParams() external view returns (MinterParams memory) {
        MinterState storage s = ms();
        return
            MinterParams(
                s.minimumCollateralizationRatio,
                s.minimumDebtValue,
                s.liquidationThreshold,
                s.liquidationIncentiveMultiplier,
                s.feeRecipient,
                s.extOracleDecimals,
                s.oracleDeviationPct
            );
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Assets                                   */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IStateFacet
    function krAssetExists(address _kreskoAsset) external view returns (bool exists) {
        return ms().kreskoAssets[_kreskoAsset].exists;
    }

    /// @inheritdoc IStateFacet
    function kreskoAsset(address _kreskoAsset) external view returns (KrAsset memory asset) {
        return ms().kreskoAsset(_kreskoAsset);
    }

    /// @inheritdoc IStateFacet
    function collateralExists(address _collateralAsset) external view returns (bool exists) {
        return ms().collateralAssets[_collateralAsset].exists;
    }

    /// @inheritdoc IStateFacet
    function collateralAsset(address _collateralAsset) external view returns (CollateralAsset memory asset) {
        return ms().collateralAssets[_collateralAsset];
    }

    /// @inheritdoc IStateFacet
    function getCollateralValueAndOraclePrice(
        address _collateralAsset,
        uint256 _amount,
        bool _ignoreCollateralFactor
    ) external view returns (uint256 value, uint256 oraclePrice) {
        return ms().getCollateralValueAndOraclePrice(_collateralAsset, _amount, _ignoreCollateralFactor);
    }

    /// @inheritdoc IStateFacet
    function getKrAssetValue(
        address _kreskoAsset,
        uint256 _amount,
        bool _ignoreKFactor
    ) external view returns (uint256 value) {
        return ms().getKrAssetValue(_kreskoAsset, _amount, _ignoreKFactor);
    }
}
