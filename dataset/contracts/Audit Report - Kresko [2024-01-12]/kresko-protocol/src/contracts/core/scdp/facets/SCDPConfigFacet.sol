// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Arrays} from "libs/Arrays.sol";
import {DSModifiers} from "diamond/DSModifiers.sol";
import {Asset} from "common/Types.sol";
import {Modifiers} from "common/Modifiers.sol";
import {cs} from "common/State.sol";
import {Percents, Role} from "common/Constants.sol";
import {Errors} from "common/Errors.sol";
import {Validations} from "common/Validations.sol";

import {ISCDPConfigFacet} from "scdp/interfaces/ISCDPConfigFacet.sol";
import {SCDPInitArgs, SwapRouteSetter, SCDPParameters} from "scdp/STypes.sol";
import {scdp, sdi} from "scdp/SState.sol";
import {SEvent} from "scdp/SEvent.sol";

contract SCDPConfigFacet is ISCDPConfigFacet, DSModifiers, Modifiers {
    using Arrays for address[];

    /// @inheritdoc ISCDPConfigFacet
    function initializeSCDP(SCDPInitArgs calldata args) external initializer(4) initializeAsAdmin {
        setMinCollateralRatioSCDP(args.minCollateralRatio);
        setLiquidationThresholdSCDP(args.liquidationThreshold);
        Validations.validateOraclePrecision(args.sdiPricePrecision);
        sdi().sdiPricePrecision = args.sdiPricePrecision;
    }

    /// @inheritdoc ISCDPConfigFacet
    function getParametersSCDP() external view override returns (SCDPParameters memory) {
        return
            SCDPParameters({
                feeAsset: scdp().feeAsset,
                minCollateralRatio: scdp().minCollateralRatio,
                liquidationThreshold: scdp().liquidationThreshold,
                maxLiquidationRatio: scdp().maxLiquidationRatio,
                sdiPricePrecision: sdi().sdiPricePrecision
            });
    }

    function setFeeAssetSCDP(address _assetAddr) external onlyRole(Role.ADMIN) {
        cs().onlySharedCollateral(_assetAddr);
        scdp().feeAsset = _assetAddr;
    }

    /// @inheritdoc ISCDPConfigFacet
    function setMinCollateralRatioSCDP(uint32 _newMCR) public onlyRole(Role.ADMIN) {
        Validations.validateMinCollateralRatio(_newMCR, scdp().liquidationThreshold);

        emit SEvent.SCDPMinCollateralRatioUpdated(scdp().minCollateralRatio, _newMCR);
        scdp().minCollateralRatio = _newMCR;
    }

    /// @inheritdoc ISCDPConfigFacet
    function setLiquidationThresholdSCDP(uint32 _newLT) public onlyRole(Role.ADMIN) {
        Validations.validateLiquidationThreshold(_newLT, scdp().minCollateralRatio);

        uint32 newMLR = _newLT + Percents.ONE;

        emit SEvent.SCDPLiquidationThresholdUpdated(scdp().liquidationThreshold, _newLT, newMLR);
        emit SEvent.SCDPMaxLiquidationRatioUpdated(scdp().maxLiquidationRatio, newMLR);

        scdp().liquidationThreshold = _newLT;
        scdp().maxLiquidationRatio = newMLR;
    }

    function setMaxLiquidationRatioSCDP(uint32 _newMLR) external onlyRole(Role.ADMIN) {
        Validations.validateMaxLiquidationRatio(_newMLR, scdp().liquidationThreshold);

        emit SEvent.SCDPMaxLiquidationRatioUpdated(scdp().maxLiquidationRatio, _newMLR);
        scdp().maxLiquidationRatio = _newMLR;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Assets                                   */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ISCDPConfigFacet
    function setDepositLimitSCDP(address _assetAddr, uint256 _newDepositLimitSCDP) external onlyRole(Role.ADMIN) {
        Asset storage asset = cs().onlySharedCollateral(_assetAddr);
        asset.depositLimitSCDP = _newDepositLimitSCDP;
    }

    /// @inheritdoc ISCDPConfigFacet
    function setKrAssetLiqIncentiveSCDP(address _assetAddr, uint16 _newLiqIncentiveSCDP) external onlyRole(Role.ADMIN) {
        Validations.validateLiqIncentive(_assetAddr, _newLiqIncentiveSCDP);
        Asset storage asset = cs().onlySwapMintable(_assetAddr);

        emit SEvent.SCDPLiquidationIncentiveUpdated(
            Errors.symbol(_assetAddr),
            _assetAddr,
            asset.liqIncentiveSCDP,
            _newLiqIncentiveSCDP
        );
        asset.liqIncentiveSCDP = _newLiqIncentiveSCDP;
    }

    /// @inheritdoc ISCDPConfigFacet
    function setAssetIsSharedCollateralSCDP(address _assetAddr, bool _enabled) external onlyRole(Role.ADMIN) {
        Asset storage asset = cs().onlyExistingAsset(_assetAddr);
        if (_enabled && asset.isSharedCollateral) revert Errors.ASSET_ALREADY_ENABLED(Errors.id(_assetAddr));
        if (!_enabled && !asset.isSharedCollateral) revert Errors.ASSET_ALREADY_DISABLED(Errors.id(_assetAddr));
        asset.isSharedCollateral = _enabled;

        if (!Validations.validateSCDPDepositAsset(_assetAddr, asset)) {
            asset.depositLimitSCDP = 0;
            return;
        }
        scdp().collaterals.pushUnique(_assetAddr);
    }

    /// @inheritdoc ISCDPConfigFacet
    function setAssetIsSwapMintableSCDP(address _assetAddr, bool _enabled) external onlyRole(Role.ADMIN) {
        Asset storage asset = cs().onlyExistingAsset(_assetAddr);
        if (_enabled && asset.isSwapMintable) revert Errors.ASSET_ALREADY_ENABLED(Errors.id(_assetAddr));
        if (!_enabled && !asset.isSwapMintable) revert Errors.ASSET_ALREADY_DISABLED(Errors.id(_assetAddr));

        asset.isSwapMintable = _enabled;

        if (!Validations.validateSCDPKrAsset(_assetAddr, asset)) {
            if (asset.toRebasingAmount(scdp().assetData[_assetAddr].debt) != 0) {
                revert Errors.CANNOT_REMOVE_SWAPPABLE_ASSET_THAT_HAS_DEBT(Errors.id(_assetAddr));
            }
            scdp().krAssets.removeExisting(_assetAddr);
            asset.liqIncentiveSCDP = 0;
            return;
        }
        scdp().collaterals.pushUnique(_assetAddr);
        scdp().krAssets.pushUnique(_assetAddr);
    }

    function setAssetIsSharedOrSwappedCollateralSCDP(address _assetAddr, bool _enabled) external onlyRole(Role.ADMIN) {
        Asset storage asset = cs().onlyExistingAsset(_assetAddr);
        if (_enabled && asset.isSharedOrSwappedCollateral) revert Errors.ASSET_ALREADY_ENABLED(Errors.id(_assetAddr));
        if (!_enabled && !asset.isSharedOrSwappedCollateral) revert Errors.ASSET_ALREADY_DISABLED(Errors.id(_assetAddr));

        if (_enabled) {
            scdp().collaterals.pushUnique(_assetAddr);
        } else {
            if (scdp().userDepositAmount(_assetAddr, asset) != 0) {
                revert Errors.CANNOT_REMOVE_COLLATERAL_THAT_HAS_USER_DEPOSITS(Errors.id(_assetAddr));
            }
            scdp().collaterals.removeExisting(_assetAddr);
            asset.depositLimitSCDP = 0;
        }
        asset.isSharedOrSwappedCollateral = _enabled;
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Swap                                    */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc ISCDPConfigFacet
    function setAssetSwapFeesSCDP(
        address _assetAddr,
        uint16 _openFee,
        uint16 _closeFee,
        uint16 _protocolFee
    ) external onlyRole(Role.ADMIN) {
        Validations.validateFees(_assetAddr, _openFee, _closeFee);
        Validations.validateFees(_assetAddr, _protocolFee, _protocolFee);

        cs().assets[_assetAddr].swapInFeeSCDP = _openFee;
        cs().assets[_assetAddr].swapOutFeeSCDP = _closeFee;
        cs().assets[_assetAddr].protocolFeeShareSCDP = _protocolFee;

        emit SEvent.FeeSet(_assetAddr, _openFee, _closeFee, _protocolFee);
    }

    /// @inheritdoc ISCDPConfigFacet
    function setSwapRoutesSCDP(SwapRouteSetter[] calldata _pairs) external onlyRole(Role.ADMIN) {
        for (uint256 i; i < _pairs.length; i++) {
            scdp().isRoute[_pairs[i].assetIn][_pairs[i].assetOut] = _pairs[i].enabled;
            scdp().isRoute[_pairs[i].assetOut][_pairs[i].assetIn] = _pairs[i].enabled;

            emit SEvent.PairSet(_pairs[i].assetIn, _pairs[i].assetOut, _pairs[i].enabled);
            emit SEvent.PairSet(_pairs[i].assetOut, _pairs[i].assetIn, _pairs[i].enabled);
        }
    }

    /// @inheritdoc ISCDPConfigFacet
    function setSingleSwapRouteSCDP(SwapRouteSetter calldata _pair) external onlyRole(Role.ADMIN) {
        scdp().isRoute[_pair.assetIn][_pair.assetOut] = _pair.enabled;
        emit SEvent.PairSet(_pair.assetIn, _pair.assetOut, _pair.enabled);
    }
}
