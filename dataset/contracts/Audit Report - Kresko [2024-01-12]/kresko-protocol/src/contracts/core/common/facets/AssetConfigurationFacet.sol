// solhint-disable avoid-low-level-calls
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;
import {CommonConfigurationFacet} from "common/facets/CommonConfigurationFacet.sol";
import {IAssetConfigurationFacet} from "common/interfaces/IAssetConfigurationFacet.sol";
import {DSModifiers} from "diamond/DSModifiers.sol";
import {Modifiers} from "common/Modifiers.sol";

import {WadRay} from "libs/WadRay.sol";
import {Arrays} from "libs/Arrays.sol";
import {Strings} from "libs/Strings.sol";

import {scdp} from "scdp/SState.sol";
import {MEvent} from "minter/MEvent.sol";
import {ms} from "minter/MState.sol";

import {Errors} from "common/Errors.sol";
import {Role, Enums} from "common/Constants.sol";
import {Asset, FeedConfiguration} from "common/Types.sol";
import {cs} from "common/State.sol";
import {Validations} from "common/Validations.sol";

// solhint-disable code-complexity
contract AssetConfigurationFacet is IAssetConfigurationFacet, Modifiers, DSModifiers {
    using Strings for bytes32;
    using Arrays for address[];
    using Arrays for address[2];
    using Validations for Asset;
    using Validations for address;

    /// @inheritdoc IAssetConfigurationFacet
    function addAsset(
        address _assetAddr,
        Asset memory _config,
        address[2] memory _feeds
    ) external onlyRole(Role.ADMIN) returns (Asset memory) {
        (string memory symbol, string memory tickerStr, uint8 decimals) = _assetAddr.validateAddAssetArgs(_config);
        _config.decimals = decimals;

        if (Validations.validateMinterCollateral(_assetAddr, _config)) {
            ms().collaterals.push(_assetAddr);

            emit MEvent.CollateralAssetAdded(
                tickerStr,
                symbol,
                _assetAddr,
                _config.factor,
                _config.anchor,
                _config.liqIncentive
            );
        }
        if (Validations.validateMinterKrAsset(_assetAddr, _config)) {
            emit MEvent.KreskoAssetAdded(
                tickerStr,
                symbol,
                _assetAddr,
                _config.anchor,
                _config.kFactor,
                _config.maxDebtMinter,
                _config.closeFee,
                _config.openFee
            );
            ms().krAssets.push(_assetAddr);
        }
        if (Validations.validateSCDPDepositAsset(_assetAddr, _config)) {
            _config.liquidityIndexSCDP = uint128(WadRay.RAY);
        }
        if (Validations.validateSCDPKrAsset(_assetAddr, _config)) {
            scdp().krAssets.push(_assetAddr);
        }
        if (_config.isSwapMintable || _config.isSharedCollateral) {
            scdp().isEnabled[_assetAddr] = true;
            scdp().collaterals.push(_assetAddr);
        }

        /* ------------------------------- Save Asset ------------------------------- */
        cs().assets[_assetAddr] = _config;

        // possibly save feeds
        if (!_feeds.empty()) {
            address(this).delegatecall(
                abi.encodeWithSelector(
                    CommonConfigurationFacet.setFeedsForTicker.selector,
                    _config.ticker,
                    FeedConfiguration(_config.oracles, _feeds)
                )
            );
        }
        Validations.validateRawAssetPrice(_assetAddr);
        return _config;
    }

    /// @inheritdoc IAssetConfigurationFacet
    function updateAsset(address _assetAddr, Asset memory _config) external onlyRole(Role.ADMIN) returns (Asset memory) {
        (string memory symbol, string memory tickerStr, Asset storage asset) = _assetAddr.validateUpdateAssetArgs(_config);

        asset.ticker = _config.ticker;
        asset.oracles = _config.oracles;

        if (Validations.validateMinterCollateral(_assetAddr, _config)) {
            asset.factor = _config.factor;
            asset.liqIncentive = _config.liqIncentive;
            asset.isMinterCollateral = true;
            ms().collaterals.pushUnique(_assetAddr);
            emit MEvent.CollateralAssetUpdated(
                tickerStr,
                symbol,
                _assetAddr,
                _config.factor,
                _config.anchor,
                _config.liqIncentive
            );
        } else if (asset.isMinterCollateral) {
            asset.liqIncentive = 0;
            asset.isMinterCollateral = false;
            ms().collaterals.removeExisting(_assetAddr);
        }

        if (Validations.validateMinterKrAsset(_assetAddr, _config)) {
            asset.kFactor = _config.kFactor;
            asset.maxDebtMinter = _config.maxDebtMinter;
            asset.closeFee = _config.closeFee;
            asset.openFee = _config.openFee;
            asset.anchor = _config.anchor;
            asset.isMinterMintable = true;
            ms().krAssets.pushUnique(_assetAddr);

            emit MEvent.KreskoAssetUpdated(
                tickerStr,
                symbol,
                _assetAddr,
                _config.anchor,
                _config.kFactor,
                _config.maxDebtMinter,
                _config.closeFee,
                _config.openFee
            );
        } else if (asset.isMinterMintable) {
            asset.maxDebtMinter = 0;
            asset.isMinterMintable = false;
            ms().krAssets.removeExisting(_assetAddr);
        }

        if (Validations.validateSCDPDepositAsset(_assetAddr, _config)) {
            if (asset.liquidityIndexSCDP == 0) {
                asset.liquidityIndexSCDP = uint128(WadRay.RAY);
            }
            asset.depositLimitSCDP = _config.depositLimitSCDP;
            asset.isSharedCollateral = true;
        } else if (asset.isSharedCollateral) {
            asset.depositLimitSCDP = 0;
            asset.isSharedCollateral = false;
        }

        if (Validations.validateSCDPKrAsset(_assetAddr, _config)) {
            asset.swapInFeeSCDP = _config.swapInFeeSCDP;
            asset.swapOutFeeSCDP = _config.swapOutFeeSCDP;
            asset.protocolFeeShareSCDP = _config.protocolFeeShareSCDP;
            asset.liqIncentiveSCDP = _config.liqIncentiveSCDP;
            asset.maxDebtSCDP = _config.maxDebtSCDP;
            asset.isSwapMintable = true;
            scdp().krAssets.pushUnique(_assetAddr);
        } else if (asset.isSwapMintable) {
            asset.isSwapMintable = false;
            asset.liqIncentiveSCDP = 0;
            scdp().krAssets.removeExisting(_assetAddr);
        }

        if (asset.isSharedCollateral || asset.isSwapMintable) {
            asset.isSharedOrSwappedCollateral = true;
            scdp().collaterals.pushUnique(_assetAddr);
        } // no deleting collaterals here

        Validations.validateRawAssetPrice(_assetAddr);

        return asset;
    }

    /// @inheritdoc IAssetConfigurationFacet
    function setAssetCFactor(address _assetAddr, uint16 _newFactor) public onlyRole(Role.ADMIN) {
        Asset storage asset = cs().onlyExistingAsset(_assetAddr);
        Validations.validateCFactor(_assetAddr, _newFactor);

        emit MEvent.CFactorUpdated(MEvent.symbol(_assetAddr), _assetAddr, asset.factor, _newFactor);
        asset.factor = _newFactor;
    }

    /// @inheritdoc IAssetConfigurationFacet
    function setAssetKFactor(address _assetAddr, uint16 _newFactor) public onlyRole(Role.ADMIN) {
        Asset storage asset = cs().onlyExistingAsset(_assetAddr);
        Validations.validateKFactor(_assetAddr, _newFactor);

        emit MEvent.KFactorUpdated(MEvent.symbol(_assetAddr), _assetAddr, asset.kFactor, _newFactor);
        asset.kFactor = _newFactor;
    }

    /// @inheritdoc IAssetConfigurationFacet
    function setAssetOracleOrder(address _assetAddr, Enums.OracleType[2] memory _newOracleOrder) external onlyRole(Role.ADMIN) {
        Asset storage asset = cs().assets[_assetAddr];
        if (!asset.exists()) revert Errors.ASSET_DOES_NOT_EXIST(Errors.id(_assetAddr));
        asset.oracles = _newOracleOrder;
        Validations.validateRawAssetPrice(_assetAddr);
    }

    /// @inheritdoc IAssetConfigurationFacet
    function validateAssetConfig(address _assetAddr, Asset memory _config) external view returns (bool) {
        return Validations.validateAsset(_assetAddr, _config);
    }
}
