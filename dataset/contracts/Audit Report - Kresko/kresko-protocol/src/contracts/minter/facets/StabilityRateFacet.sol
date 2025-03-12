// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {Arrays} from "../../libs/Arrays.sol";
import {WadRay} from "../../libs/WadRay.sol";
import {InterestRateEvent} from "../../libs/Events.sol";
import {LibStabilityRate} from "../libs/LibStabilityRate.sol";
import {LibDecimals} from "../libs/LibDecimals.sol";
import {StabilityRateConfig} from "../InterestRateState.sol";
import {ms} from "../MinterStorage.sol";
import {irs} from "../InterestRateState.sol";
import {IERC20Permit} from "../../shared/IERC20Permit.sol";
import {IStabilityRateFacet} from "../interfaces/IStabilityRateFacet.sol";
import {DiamondModifiers, Role} from "../../diamond/DiamondModifiers.sol";
import {MinterModifiers, Error} from "../MinterModifiers.sol";
import {SafeERC20, IERC20Permit} from "../../shared/SafeERC20.sol";

/* solhint-disable var-name-mixedcase */

// Stability Rate setup params
struct StabilityRateParams {
    uint128 stabilityRateBase;
    uint128 rateSlope1;
    uint128 rateSlope2;
    uint128 optimalPriceRate;
    uint128 priceRateDelta;
}

/**
 * @title Stability rate facet
 * @author Kresko
 * @notice Stability rate related views and state operations
 * @dev Uses both MinterState (ms) and InterestRateState (irs)
 */
contract StabilityRateFacet is IStabilityRateFacet, MinterModifiers, DiamondModifiers {
    using Arrays for address[];
    using SafeERC20 for IERC20Permit;
    using LibStabilityRate for StabilityRateConfig;
    using WadRay for uint256;
    using LibDecimals for uint256;

    /* -------------------------------------------------------------------------- */
    /*                              ASSET STATE WRITES                            */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IStabilityRateFacet
    function setupStabilityRateParams(address _asset, StabilityRateParams memory _setup) external onlyRole(Role.ADMIN) {
        require(irs().kiss != address(0), Error.KISS_NOT_SET);
        require(irs().srAssets[_asset].asset == address(0), Error.STABILITY_RATES_ALREADY_INITIALIZED);
        require(WadRay.RAY >= _setup.optimalPriceRate, Error.INVALID_OPTIMAL_RATE);
        require(WadRay.RAY >= _setup.priceRateDelta, Error.INVALID_PRICE_RATE_DELTA);

        irs().srAssets[_asset] = StabilityRateConfig({
            debtIndex: uint128(WadRay.RAY),
            stabilityRateBase: _setup.stabilityRateBase,
            // solhint-disable not-rely-on-time
            lastUpdateTimestamp: uint40(block.timestamp),
            asset: _asset,
            rateSlope1: _setup.rateSlope1,
            rateSlope2: _setup.rateSlope2,
            optimalPriceRate: _setup.optimalPriceRate,
            priceRateDelta: _setup.priceRateDelta,
            stabilityRate: uint128(WadRay.RAY)
        });

        emit InterestRateEvent.StabilityRateConfigured(
            _asset,
            _setup.stabilityRateBase,
            _setup.priceRateDelta,
            _setup.rateSlope1,
            _setup.rateSlope2
        );
    }

    /// @inheritdoc IStabilityRateFacet
    function updateStabilityRateParams(
        address _asset,
        StabilityRateParams memory _setup
    ) external onlyRole(Role.ADMIN) {
        require(irs().srAssets[_asset].asset == _asset, Error.STABILITY_RATES_NOT_INITIALIZED);
        require(WadRay.RAY >= _setup.optimalPriceRate, Error.INVALID_OPTIMAL_RATE);
        require(WadRay.RAY >= _setup.priceRateDelta, Error.INVALID_PRICE_RATE_DELTA);

        irs().srAssets[_asset].rateSlope1 = _setup.rateSlope1;
        irs().srAssets[_asset].rateSlope2 = _setup.rateSlope2;
        irs().srAssets[_asset].optimalPriceRate = _setup.optimalPriceRate;
        irs().srAssets[_asset].priceRateDelta = _setup.priceRateDelta;
        irs().srAssets[_asset].stabilityRateBase = _setup.stabilityRateBase;

        emit InterestRateEvent.StabilityRateConfigured(
            _asset,
            _setup.stabilityRateBase,
            _setup.priceRateDelta,
            _setup.rateSlope1,
            _setup.rateSlope2
        );
    }

    /// @inheritdoc IStabilityRateFacet
    function updateStabilityRateAndIndexForAsset(address _asset) external {
        irs().srAssets[_asset].updateDebtIndex();
        irs().srAssets[_asset].updateStabilityRate();
    }

    function updateKiss(address _kiss) external onlyRole(Role.ADMIN) {
        irs().kiss = _kiss;
        emit InterestRateEvent.KISSUpdated(_kiss);
    }

    /* -------------------------------------------------------------------------- */
    /*                                REPAYMENT                                   */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IStabilityRateFacet
    function repayStabilityRateInterestPartial(
        address _account,
        address _kreskoAsset,
        uint256 _kissRepayAmount
    ) external nonReentrant kreskoAssetExists(_kreskoAsset) {
        // Update debt index for the asset
        uint256 newDebtIndex = irs().srAssets[_kreskoAsset].updateDebtIndex();

        // Get the accrued interest in repayment token
        (, uint256 maxKissRepayAmount) = ms().getKreskoAssetDebtInterest(_account, _kreskoAsset);
        require(_kissRepayAmount < maxKissRepayAmount, Error.INTEREST_REPAY_NOT_PARTIAL);

        // If no interest has accrued or 0 amount was supplied as parameter - no further operations needed
        // Do not revert because we want the preserve new debt index and stability rate
        // Also removes the need to check if the kresko asset exists as the maxKissAmount will return 0
        if (_kissRepayAmount == 0 || maxKissRepayAmount == 0) {
            // Update stability rate for asset
            irs().srAssets[_kreskoAsset].updateStabilityRate();
            return;
        }

        // Transfer the accrued interest
        IERC20Permit(irs().kiss).safeTransferFrom(msg.sender, ms().feeRecipient, _kissRepayAmount);
        uint256 assetAmount = _kissRepayAmount.divByPrice(
            ms().kreskoAssets[_kreskoAsset].uintAggregatePrice(ms().oracleDeviationPct)
        );
        uint256 amountScaled = assetAmount.wadToRay().rayDiv(newDebtIndex);
        // Update scaled values for the user
        irs().srUserInfo[_account][_kreskoAsset].debtScaled -= uint128(amountScaled);
        irs().srUserInfo[_account][_kreskoAsset].lastDebtIndex = uint128(newDebtIndex);
        // Update stability rate for asset
        irs().srAssets[_kreskoAsset].updateStabilityRate();

        // Emit event with the account, asset and amount repaid
        emit InterestRateEvent.StabilityRateInterestRepaid(_account, _kreskoAsset, _kissRepayAmount);
    }

    /// @inheritdoc IStabilityRateFacet
    function repayFullStabilityRateInterest(
        address _account,
        address _kreskoAsset
    ) external nonReentrant kreskoAssetExists(_kreskoAsset) returns (uint256 kissRepayAmount) {
        return ms().repayFullStabilityRateInterest(_account, _kreskoAsset);
    }

    /// @inheritdoc IStabilityRateFacet
    function batchRepayFullStabilityRateInterest(
        address _account
    ) external nonReentrant returns (uint256 kissRepayAmount) {
        address[] memory mintedKreskoAssets = ms().getMintedKreskoAssets(_account);
        for (uint256 i; i < mintedKreskoAssets.length; i++) {
            kissRepayAmount += ms().repayFullStabilityRateInterest(_account, mintedKreskoAssets[i]);
        }
        emit InterestRateEvent.StabilityRateInterestBatchRepaid(_account, kissRepayAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   VIEWS                                    */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IStabilityRateFacet
    function getStabilityRateForAsset(address _asset) external view returns (uint256 stabilityRate) {
        return irs().srAssets[_asset].calculateStabilityRate();
    }

    /// @inheritdoc IStabilityRateFacet
    function getPriceRateForAsset(address _asset) external view returns (uint256 priceRate) {
        return irs().srAssets[_asset].getPriceRate();
    }

    /// @inheritdoc IStabilityRateFacet
    function getDebtIndexForAsset(address _asset) external view returns (uint256 debtIndex) {
        return irs().srAssets[_asset].getNormalizedDebtIndex();
    }

    /// @inheritdoc IStabilityRateFacet
    function getStabilityRateConfigurationForAsset(address _asset) external view returns (StabilityRateConfig memory) {
        return irs().srAssets[_asset];
    }

    /// @inheritdoc IStabilityRateFacet
    function kiss() external view returns (address) {
        return irs().kiss;
    }

    function getLastDebtIndexForAccount(
        address _account,
        address _asset
    ) external view returns (uint128 lastDebtIndex) {
        return irs().srUserInfo[_account][_asset].lastDebtIndex;
    }
}
