// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
import {IERC165} from "vendor/IERC165.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";
import {IKreskoAsset} from "kresko-asset/IKreskoAsset.sol";
import {IKreskoAssetIssuer} from "kresko-asset/IKreskoAssetIssuer.sol";
import {IKISS} from "kiss/interfaces/IKISS.sol";

import {Strings} from "libs/Strings.sol";
import {PercentageMath} from "libs/PercentageMath.sol";

import {Errors} from "common/Errors.sol";
import {Asset, RawPrice} from "common/Types.sol";
import {Role, Percents, Constants} from "common/Constants.sol";
import {cs} from "common/State.sol";
import {rawPrice} from "common/funcs/Prices.sol";

import {scdp} from "scdp/SState.sol";
import {ms, MinterState} from "minter/MState.sol";

// solhint-disable code-complexity
library Validations {
    using PercentageMath for uint256;
    using PercentageMath for uint16;
    using Strings for bytes32;

    function validatePriceDeviationPct(uint16 _deviationPct) internal pure {
        if (_deviationPct > Percents.MAX_DEVIATION) {
            revert Errors.INVALID_ORACLE_DEVIATION(_deviationPct, Percents.MAX_DEVIATION);
        }
    }

    function validateMinDebtValue(uint256 _minDebtValue) internal pure {
        if (_minDebtValue > Constants.MAX_MIN_DEBT_VALUE) {
            revert Errors.INVALID_MIN_DEBT(_minDebtValue, Constants.MAX_MIN_DEBT_VALUE);
        }
    }

    function validateFeeRecipient(address _feeRecipient) internal pure {
        if (_feeRecipient == address(0)) revert Errors.INVALID_FEE_RECIPIENT(_feeRecipient);
    }

    function validateOraclePrecision(uint256 _decimalPrecision) internal pure {
        if (_decimalPrecision < Constants.MIN_ORACLE_DECIMALS) {
            revert Errors.INVALID_PRICE_PRECISION(_decimalPrecision, Constants.MIN_ORACLE_DECIMALS);
        }
    }

    function validateMinCollateralRatio(uint256 _minCollateralRatio, uint256 _liqThreshold) internal pure {
        if (_minCollateralRatio < Percents.MIN_MCR) {
            revert Errors.INVALID_MCR(_minCollateralRatio, Percents.MIN_MCR);
        }
        // this should never be hit, but just in case
        if (_minCollateralRatio < _liqThreshold) {
            revert Errors.INVALID_MCR(_minCollateralRatio, _liqThreshold);
        }
    }

    function validateLiquidationThreshold(uint256 _liquidationThreshold, uint256 _minCollateralRatio) internal pure {
        if (_liquidationThreshold < Percents.MIN_LT || _liquidationThreshold >= _minCollateralRatio) {
            revert Errors.INVALID_LIQ_THRESHOLD(_liquidationThreshold, Percents.MIN_LT, _minCollateralRatio);
        }
    }

    function validateMaxLiquidationRatio(uint256 _maxLiquidationRatio, uint256 _liquidationThreshold) internal pure {
        if (_maxLiquidationRatio < _liquidationThreshold) {
            revert Errors.MLR_CANNOT_BE_LESS_THAN_LIQ_THRESHOLD(_maxLiquidationRatio, _liquidationThreshold);
        }
    }

    function validateAddAssetArgs(
        address _assetAddr,
        Asset memory _config
    ) internal view returns (string memory symbol, string memory tickerStr, uint8 decimals) {
        if (_assetAddr == address(0)) revert Errors.ZERO_ADDRESS();

        symbol = IERC20(_assetAddr).symbol();
        if (cs().assets[_assetAddr].exists()) revert Errors.ASSET_ALREADY_EXISTS(Errors.ID(symbol, _assetAddr));

        tickerStr = _config.ticker.toString();
        if (_config.ticker == Constants.ZERO_BYTES32) revert Errors.INVALID_TICKER(Errors.ID(symbol, _assetAddr), tickerStr);

        decimals = IERC20(_assetAddr).decimals();
        validateDecimals(_assetAddr, decimals);
    }

    function validateUpdateAssetArgs(
        address _assetAddr,
        Asset memory _config
    ) internal view returns (string memory symbol, string memory tickerStr, Asset storage asset) {
        if (_assetAddr == address(0)) revert Errors.ZERO_ADDRESS();

        symbol = IERC20(_assetAddr).symbol();
        asset = cs().assets[_assetAddr];

        if (!asset.exists()) revert Errors.ASSET_DOES_NOT_EXIST(Errors.ID(symbol, _assetAddr));

        tickerStr = _config.ticker.toString();
        if (_config.ticker == Constants.ZERO_BYTES32) revert Errors.INVALID_TICKER(Errors.ID(symbol, _assetAddr), tickerStr);
    }

    function validateAsset(address _assetAddr, Asset memory _config) internal view returns (bool) {
        validateMinterCollateral(_assetAddr, _config);
        validateMinterKrAsset(_assetAddr, _config);
        validateSCDPDepositAsset(_assetAddr, _config);
        validateSCDPKrAsset(_assetAddr, _config);
        validateRawAssetPrice(_assetAddr);
        validateLiqConfig(_assetAddr);
        return true;
    }

    function validateMinterCollateral(
        address _assetAddr,
        Asset memory _config
    ) internal view returns (bool isMinterCollateral) {
        if (_config.isMinterCollateral) {
            validateCFactor(_assetAddr, _config.factor);
            validateLiqIncentive(_assetAddr, _config.liqIncentive);
            return true;
        }
    }

    function validateSCDPDepositAsset(
        address _assetAddr,
        Asset memory _config
    ) internal view returns (bool isSharedCollateral) {
        if (_config.isSharedCollateral) {
            validateCFactor(_assetAddr, _config.factor);
            return true;
        }
    }

    function validateMinterKrAsset(address _assetAddr, Asset memory _config) internal view returns (bool isMinterKrAsset) {
        if (_config.isMinterMintable) {
            validateKFactor(_assetAddr, _config.kFactor);
            validateFees(_assetAddr, _config.openFee, _config.closeFee);
            validateKrAssetContract(_assetAddr, _config.anchor);
            return true;
        }
    }

    function validateSCDPKrAsset(address _assetAddr, Asset memory _config) internal view returns (bool isSwapMintable) {
        if (_config.isSwapMintable) {
            validateFees(_assetAddr, _config.swapInFeeSCDP, _config.swapOutFeeSCDP);
            validateFees(_assetAddr, _config.protocolFeeShareSCDP, _config.protocolFeeShareSCDP);
            validateLiqIncentive(_assetAddr, _config.liqIncentiveSCDP);
            return true;
        }
    }

    function validateSDICoverAsset(address _assetAddr) internal view returns (Asset storage asset) {
        asset = cs().assets[_assetAddr];
        if (!asset.exists()) revert Errors.ASSET_DOES_NOT_EXIST(Errors.id(_assetAddr));
        if (asset.isCoverAsset) revert Errors.ASSET_ALREADY_ENABLED(Errors.id(_assetAddr));
        validateRawAssetPrice(_assetAddr);
    }

    function validateKrAssetContract(address _assetAddr, address _anchorAddr) internal view {
        IERC165 asset = IERC165(_assetAddr);
        if (!asset.supportsInterface(type(IKISS).interfaceId) && !asset.supportsInterface(type(IKreskoAsset).interfaceId)) {
            revert Errors.INVALID_CONTRACT_KRASSET(Errors.id(_assetAddr));
        }
        if (!IERC165(_anchorAddr).supportsInterface(type(IKreskoAssetIssuer).interfaceId)) {
            revert Errors.INVALID_CONTRACT_KRASSET_ANCHOR(Errors.id(_anchorAddr), Errors.id(_assetAddr));
        }
        if (!IKreskoAsset(_assetAddr).hasRole(Role.OPERATOR, address(this))) {
            revert Errors.INVALID_KRASSET_OPERATOR(
                Errors.id(_assetAddr),
                address(this),
                IKreskoAsset(_assetAddr).getRoleMember(Role.OPERATOR, 0)
            );
        }
    }

    function ensureUnique(address _asset1Addr, address _asset2Addr) internal view {
        if (_asset1Addr == _asset2Addr) revert Errors.IDENTICAL_ASSETS(Errors.id(_asset1Addr));
    }

    function validateRoute(address _assetInAddr, address _assetOutAddr) internal view {
        if (!scdp().isRoute[_assetInAddr][_assetOutAddr])
            revert Errors.SWAP_ROUTE_NOT_ENABLED(Errors.id(_assetInAddr), Errors.id(_assetOutAddr));
    }

    function validateDecimals(address _assetAddr, uint8 _decimals) internal view {
        if (_decimals == 0) {
            revert Errors.INVALID_DECIMALS(Errors.id(_assetAddr), _decimals);
        }
    }

    function validateVaultAssetDecimals(address _assetAddr, uint8 _decimals) internal view {
        if (_decimals == 0) {
            revert Errors.INVALID_DECIMALS(Errors.id(_assetAddr), _decimals);
        }
        if (_decimals > 18) revert Errors.INVALID_DECIMALS(Errors.id(_assetAddr), _decimals);
    }

    function validateUint128(address _assetAddr, uint256 _value) internal view {
        if (_value > type(uint128).max) {
            revert Errors.UINT128_OVERFLOW(Errors.id(_assetAddr), _value, type(uint128).max);
        }
    }

    function validateCFactor(address _assetAddr, uint16 _cFactor) internal view {
        if (_cFactor > Percents.HUNDRED) {
            revert Errors.INVALID_CFACTOR(Errors.id(_assetAddr), _cFactor, Percents.HUNDRED);
        }
    }

    function validateKFactor(address _assetAddr, uint16 _kFactor) internal view {
        if (_kFactor < Percents.HUNDRED) {
            revert Errors.INVALID_KFACTOR(Errors.id(_assetAddr), _kFactor, Percents.HUNDRED);
        }
    }

    function validateFees(address _assetAddr, uint16 _fee1, uint16 _fee2) internal view {
        if (_fee1 + _fee2 > Percents.HUNDRED) {
            revert Errors.INVALID_FEE(Errors.id(_assetAddr), _fee1 + _fee2, Percents.HUNDRED);
        }
    }

    function validateLiqIncentive(address _assetAddr, uint16 _liqIncentive) internal view {
        if (_liqIncentive > Percents.MAX_LIQ_INCENTIVE || _liqIncentive < Percents.MIN_LIQ_INCENTIVE) {
            revert Errors.INVALID_LIQ_INCENTIVE(
                Errors.id(_assetAddr),
                _liqIncentive,
                Percents.MIN_LIQ_INCENTIVE,
                Percents.MAX_LIQ_INCENTIVE
            );
        }
    }

    function validateLiqConfig(address _assetAddr) internal view {
        Asset storage asset = cs().assets[_assetAddr];
        if (asset.isMinterMintable) {
            address[] memory minterCollaterals = ms().collaterals;
            for (uint256 i; i < minterCollaterals.length; i++) {
                address collateralAddr = minterCollaterals[i];
                Asset storage collateral = cs().assets[collateralAddr];
                validateLiquidationMarket(collateralAddr, collateral, _assetAddr, asset);
                validateLiquidationMarket(_assetAddr, asset, collateralAddr, collateral);
            }
        }

        if (asset.isMinterCollateral) {
            address[] memory minterKrAssets = ms().krAssets;
            for (uint256 i; i < minterKrAssets.length; i++) {
                address krAssetAddr = minterKrAssets[i];
                Asset storage krAsset = cs().assets[krAssetAddr];
                validateLiquidationMarket(_assetAddr, asset, krAssetAddr, krAsset);
                validateLiquidationMarket(krAssetAddr, krAsset, _assetAddr, asset);
            }
        }

        if (asset.isSharedOrSwappedCollateral) {
            address[] memory scdpKrAssets = scdp().krAssets;
            for (uint256 i; i < scdpKrAssets.length; i++) {
                address scdpKrAssetAddr = scdpKrAssets[i];
                Asset storage scdpKrAsset = cs().assets[scdpKrAssetAddr];
                validateLiquidationMarket(_assetAddr, asset, scdpKrAssetAddr, scdpKrAsset);
                validateLiquidationMarket(scdpKrAssetAddr, scdpKrAsset, _assetAddr, asset);
            }
        }

        if (asset.isSwapMintable) {
            address[] memory scdpCollaterals = scdp().collaterals;
            for (uint256 i; i < scdpCollaterals.length; i++) {
                address scdpCollateralAddr = scdpCollaterals[i];
                Asset storage scdpCollateral = cs().assets[scdpCollateralAddr];
                validateLiquidationMarket(_assetAddr, asset, scdpCollateralAddr, scdpCollateral);
                validateLiquidationMarket(scdpCollateralAddr, scdpCollateral, _assetAddr, asset);
            }
        }
    }

    function validateLiquidationMarket(
        address _seizeAssetAddr,
        Asset storage seizeAsset,
        address _repayAssetAddr,
        Asset storage repayAsset
    ) internal view {
        if (seizeAsset.isSharedOrSwappedCollateral && repayAsset.isSwapMintable) {
            uint256 seizeReductionPct = (repayAsset.liqIncentiveSCDP.percentMul(seizeAsset.factor));
            uint256 repayIncreasePct = (repayAsset.kFactor.percentMul(scdp().maxLiquidationRatio));
            if (seizeReductionPct >= repayIncreasePct) {
                revert Errors.SCDP_ASSET_ECONOMY(
                    Errors.id(_seizeAssetAddr),
                    seizeReductionPct,
                    Errors.id(_repayAssetAddr),
                    repayIncreasePct
                );
            }
        }
        if (seizeAsset.isMinterCollateral && repayAsset.isMinterMintable) {
            uint256 seizeReductionPct = (seizeAsset.liqIncentive.percentMul(seizeAsset.factor)) + repayAsset.closeFee;
            uint256 repayIncreasePct = (repayAsset.kFactor.percentMul(ms().maxLiquidationRatio));
            if (seizeReductionPct >= repayIncreasePct) {
                revert Errors.MINTER_ASSET_ECONOMY(
                    Errors.id(_seizeAssetAddr),
                    seizeReductionPct,
                    Errors.id(_repayAssetAddr),
                    repayIncreasePct
                );
            }
        }
    }

    function validateCollateralArgs(
        MinterState storage self,
        address _account,
        address _collateralAsset,
        uint256 _collateralIndex,
        uint256 _amount
    ) internal view {
        if (_amount == 0) revert Errors.ZERO_AMOUNT(Errors.id(_collateralAsset));
        if (_collateralIndex > self.depositedCollateralAssets[_account].length - 1)
            revert Errors.ELEMENT_DOES_NOT_MATCH_PROVIDED_INDEX(
                Errors.id(_collateralAsset),
                _collateralIndex,
                self.depositedCollateralAssets[_account]
            );
    }

    function rawAssetPrice(Asset storage self) internal view returns (RawPrice memory) {
        return rawPrice(self.oracles, self.ticker);
    }

    function validateRawAssetPrice(address _assetAddr) internal view {
        Asset storage asset = cs().assets[_assetAddr];
        RawPrice memory result = rawAssetPrice(asset);
        if (result.answer <= 0) {
            revert Errors.RAW_PRICE_LTE_ZERO(
                Errors.id(_assetAddr),
                asset.ticker.toString(),
                result.answer,
                uint8(result.oracle),
                result.feed
            );
        }
        if (block.timestamp - result.timestamp > cs().staleTime) {
            revert Errors.RAW_PRICE_STALE(
                Errors.id(_assetAddr),
                asset.ticker.toString(),
                result.answer,
                uint8(result.oracle),
                result.feed,
                block.timestamp - result.timestamp,
                cs().staleTime
            );
        }
    }
}
