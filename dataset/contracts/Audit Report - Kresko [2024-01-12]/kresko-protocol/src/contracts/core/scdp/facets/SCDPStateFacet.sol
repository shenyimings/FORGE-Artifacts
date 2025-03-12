// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IERC20} from "kresko-lib/token/IERC20.sol";
import {WadRay} from "libs/WadRay.sol";
import {PercentageMath} from "libs/PercentageMath.sol";
import {Percents} from "common/Constants.sol";
import {cs} from "common/State.sol";
import {Asset} from "common/Types.sol";

import {ISCDPStateFacet} from "scdp/interfaces/ISCDPStateFacet.sol";
import {AssetData, UserData, GlobalData} from "scdp/STypes.sol";
import {accountTotalDepositValues, totalCollateralValuesSCDP, totalDebtValuesAtRatioSCDP} from "scdp/funcs/SHelpers.sol";
import {collateralAmountToValues, debtAmountToValues} from "common/funcs/Helpers.sol";
import {scdp, sdi} from "scdp/SState.sol";

/**
 * @title SCDPStateFacet
 * @author Kresko
 * @notice  This facet is used to view the state of the scdp.
 */
contract SCDPStateFacet is ISCDPStateFacet {
    using WadRay for uint256;
    using PercentageMath for uint256;

    /* -------------------------------------------------------------------------- */
    /*                                  Accounts                                  */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ISCDPStateFacet
    function getAccountDepositSCDP(address _account, address _depositAsset) external view returns (uint256) {
        return scdp().accountPrincipalDeposits(_account, _depositAsset, cs().assets[_depositAsset]);
    }

    /// @inheritdoc ISCDPStateFacet
    function getAccountScaledDepositsSCDP(address _account, address _depositAsset) external view returns (uint256) {
        return scdp().accountScaledDeposits(_account, _depositAsset, cs().assets[_depositAsset]);
    }

    /// @inheritdoc ISCDPStateFacet
    function getAccountDepositFeesGainedSCDP(address _account, address _depositAsset) external view returns (uint256) {
        return
            scdp().accountScaledDeposits(_account, _depositAsset, cs().assets[_depositAsset]) -
            scdp().accountPrincipalDeposits(_account, _depositAsset, cs().assets[_depositAsset]);
    }

    /// @inheritdoc ISCDPStateFacet
    function getAccountDepositValueSCDP(address _account, address _depositAsset) external view returns (uint256) {
        Asset storage asset = cs().assets[_depositAsset];
        return asset.collateralAmountToValue(scdp().accountPrincipalDeposits(_account, _depositAsset, asset), true);
    }

    /// @inheritdoc ISCDPStateFacet
    function getAccountScaledDepositValueCDP(address _account, address _depositAsset) external view returns (uint256) {
        Asset storage asset = cs().assets[_depositAsset];
        return asset.collateralAmountToValue(scdp().accountScaledDeposits(_account, _depositAsset, asset), true);
    }

    /// @inheritdoc ISCDPStateFacet
    function getAccountTotalDepositsValueSCDP(address _account) external view returns (uint256) {
        return scdp().accountTotalDepositValue(_account, true);
    }

    /// @inheritdoc ISCDPStateFacet
    function getAccountTotalScaledDepositsValueSCDP(address _account) external view returns (uint256) {
        return scdp().accountTotalScaledDepositsValue(_account);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Collaterals                                */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ISCDPStateFacet
    function getDepositAssetsSCDP() external view returns (address[] memory result) {
        address[] memory depositAssets = scdp().collaterals;
        address[] memory results = new address[](depositAssets.length);

        uint256 index;

        for (uint256 i; i < depositAssets.length; ) {
            if (cs().assets[depositAssets[i]].isSharedCollateral) {
                results[index++] = depositAssets[i];
            }
            unchecked {
                i++;
            }
        }

        result = new address[](index);
        for (uint256 i; i < index; ) {
            result[i] = results[i];
            unchecked {
                i++;
            }
        }
    }

    function getCollateralsSCDP() external view returns (address[] memory result) {
        return scdp().collaterals;
    }

    /// @inheritdoc ISCDPStateFacet
    function getDepositsSCDP(address _depositAsset) external view returns (uint256) {
        return scdp().totalDepositAmount(_depositAsset, cs().assets[_depositAsset]);
    }

    /// @inheritdoc ISCDPStateFacet
    function getSwapDepositsSCDP(address _collateralAsset) external view returns (uint256) {
        return scdp().swapDepositAmount(_collateralAsset, cs().assets[_collateralAsset]);
    }

    /// @inheritdoc ISCDPStateFacet
    function getCollateralValueSCDP(address _depositAsset, bool _ignoreFactors) external view returns (uint256) {
        Asset storage asset = cs().assets[_depositAsset];

        return asset.collateralAmountToValue(scdp().totalDepositAmount(_depositAsset, asset), _ignoreFactors);
    }

    /// @inheritdoc ISCDPStateFacet
    function getTotalCollateralValueSCDP(bool _ignoreFactors) external view returns (uint256) {
        return scdp().totalCollateralValueSCDP(_ignoreFactors);
    }

    /* -------------------------------------------------------------------------- */
    /*                                KreskoAssets                                */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ISCDPStateFacet
    function getKreskoAssetsSCDP() external view returns (address[] memory) {
        return scdp().krAssets;
    }

    /// @inheritdoc ISCDPStateFacet
    function getDebtSCDP(address _krAsset) external view returns (uint256) {
        Asset storage asset = cs().assets[_krAsset];
        return asset.toRebasingAmount(scdp().assetData[_krAsset].debt);
    }

    /// @inheritdoc ISCDPStateFacet
    function getDebtValueSCDP(address _krAsset, bool _ignoreFactors) external view returns (uint256) {
        Asset storage asset = cs().assets[_krAsset];
        return asset.debtAmountToValue(asset.toRebasingAmount(scdp().assetData[_krAsset].debt), _ignoreFactors);
    }

    /// @inheritdoc ISCDPStateFacet
    function getTotalDebtValueSCDP(bool _ignoreFactors) external view returns (uint256) {
        return scdp().totalDebtValueAtRatioSCDP(Percents.HUNDRED, _ignoreFactors);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    MISC                                    */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ISCDPStateFacet
    function getAssetEnabledSCDP(address _assetAddr) external view returns (bool) {
        return scdp().isEnabled[_assetAddr];
    }

    function getDepositEnabledSCDP(address _assetAddr) external view returns (bool) {
        return cs().assets[_assetAddr].isSharedCollateral;
    }

    /// @inheritdoc ISCDPStateFacet
    function getSwapEnabledSCDP(address _assetIn, address _assetOut) external view returns (bool) {
        return scdp().isRoute[_assetIn][_assetOut];
    }

    function getCollateralRatioSCDP() public view returns (uint256) {
        uint256 collateralValue = scdp().totalCollateralValueSCDP(false);
        uint256 debtValue = sdi().effectiveDebtValue();
        if (debtValue == 0) return 0;
        return collateralValue.percentDiv(debtValue);
    }

    /// @inheritdoc ISCDPStateFacet
    function getStatisticsSCDP() external view returns (GlobalData memory) {
        (uint256 debtValue, uint256 debtValueAdjusted) = totalDebtValuesAtRatioSCDP(1e4);
        uint256 effectiveDebtValue = sdi().effectiveDebtValue();
        (uint256 collateralValue, uint256 collateralValueAdjusted) = totalCollateralValuesSCDP();
        return
            GlobalData({
                collateralValue: collateralValue,
                collateralValueAdjusted: collateralValueAdjusted,
                debtValue: debtValue,
                debtValueAdjusted: debtValueAdjusted,
                effectiveDebtValue: effectiveDebtValue,
                cr: debtValue == 0 ? 0 : collateralValue.percentDiv(effectiveDebtValue),
                crDebtValue: debtValue == 0 ? 0 : collateralValue.percentDiv(debtValue),
                crDebtValueAdjusted: debtValueAdjusted == 0 ? 0 : collateralValueAdjusted.percentDiv(debtValueAdjusted)
            });
    }

    function getAccountInfoSCDP(address _account, address[] memory _assets) public view returns (UserData memory result) {
        result.account = _account;
        (result.totalDepositValue, result.totalScaledDepositValue, result.deposits) = accountTotalDepositValues(
            _account,
            _assets
        );
        result.totalFeesValue = result.totalScaledDepositValue - result.totalDepositValue;
    }

    function getAccountInfosSCDP(
        address[] memory _accounts,
        address[] memory _assets
    ) external view returns (UserData[] memory result) {
        result = new UserData[](_accounts.length);

        for (uint256 i; i < _accounts.length; ) {
            address account = _accounts[i];
            result[i] = getAccountInfoSCDP(account, _assets);
            unchecked {
                i++;
            }
        }
    }

    function getAssetInfoSCDP(address _assetAddr) public view returns (AssetData memory results) {
        Asset storage asset = cs().assets[_assetAddr];
        bool isMinterMintable = asset.isSwapMintable;
        bool isMinterCollateral = asset.isSharedOrSwappedCollateral;
        uint256 depositAmount = isMinterCollateral ? scdp().totalDepositAmount(_assetAddr, asset) : 0;
        uint256 debtAmount = isMinterMintable ? asset.toRebasingAmount(scdp().assetData[_assetAddr].debt) : 0;

        (uint256 debtValue, uint256 debtValueAdjusted, uint256 krAssetPrice) = isMinterMintable
            ? debtAmountToValues(asset, debtAmount)
            : (0, 0, 0);

        (uint256 depositValue, uint256 depositValueAdjusted, uint256 collateralPrice) = isMinterCollateral
            ? collateralAmountToValues(asset, depositAmount)
            : (0, 0, 0);
        return
            AssetData({
                addr: _assetAddr,
                asset: asset,
                assetPrice: krAssetPrice > 0 ? krAssetPrice : collateralPrice,
                depositAmount: depositAmount,
                depositValue: depositValue,
                depositValueAdjusted: depositValueAdjusted,
                debtAmount: debtAmount,
                debtValue: debtValue,
                debtValueAdjusted: debtValueAdjusted,
                swapDeposits: isMinterCollateral ? scdp().swapDepositAmount(_assetAddr, asset) : 0,
                symbol: IERC20(_assetAddr).symbol()
            });
    }

    function getAssetInfosSCDP(address[] memory _assets) external view returns (AssetData[] memory results) {
        // address[] memory collateralAssets = scdp().collaterals;
        results = new AssetData[](_assets.length);

        for (uint256 i; i < _assets.length; ) {
            address asset = _assets[i];
            results[i] = getAssetInfoSCDP(asset);
            unchecked {
                i++;
            }
        }
    }
}
