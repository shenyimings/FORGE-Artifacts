// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import {IKreskoAssetIssuer} from "kresko-asset/IKreskoAssetIssuer.sol";
import {IMinterLiquidationFacet} from "minter/interfaces/IMinterLiquidationFacet.sol";

import {IERC20} from "kresko-lib/token/IERC20.sol";
import {SafeTransfer} from "kresko-lib/token/SafeTransfer.sol";
import {Arrays} from "libs/Arrays.sol";
import {WadRay} from "libs/WadRay.sol";
import {PercentageMath} from "libs/PercentageMath.sol";

import {Errors} from "common/Errors.sol";
import {valueToAmount, fromWad} from "common/funcs/Math.sol";
import {Modifiers} from "common/Modifiers.sol";
import {Asset, MaxLiqInfo} from "common/Types.sol";
import {cs} from "common/State.sol";
import {Constants, Enums} from "common/Constants.sol";

import {MEvent} from "minter/MEvent.sol";
import {ms, MinterState} from "minter/MState.sol";
import {LiquidationArgs, LiquidateExecution} from "minter/MTypes.sol";
import {handleMinterFee} from "minter/funcs/MFees.sol";

using Arrays for address[];
using WadRay for uint256;
using SafeTransfer for IERC20;
using PercentageMath for uint256;
using PercentageMath for uint16;

// solhint-disable code-complexity
/**
 * @author Kresko
 * @title MinterLiquidationFacet
 * @notice Main end-user functionality concerning liquidations within Kresko's Minter system.
 */
contract MinterLiquidationFacet is Modifiers, IMinterLiquidationFacet {
    /// @inheritdoc IMinterLiquidationFacet
    function liquidate(LiquidationArgs memory _args) external nonReentrant gate {
        if (msg.sender == _args.account) revert Errors.CANNOT_LIQUIDATE_SELF();

        Asset storage repayAsset = cs().onlyMinterMintable(_args.repayAssetAddr);
        Asset storage seizeAsset = cs().onlyMinterCollateral(_args.seizeAssetAddr);

        MinterState storage s = ms();
        // The obvious check
        s.checkAccountLiquidatable(_args.account);

        // Bound to min debt value or max liquidation value
        (uint256 repayValue, uint256 repayAmount) = repayAsset.boundRepayValue(
            _getMaxLiqValue(_args.account, repayAsset, seizeAsset, _args.seizeAssetAddr),
            _args.repayAmount
        );
        if (repayValue == 0 || repayAmount == 0) {
            revert Errors.LIQUIDATION_VALUE_IS_ZERO(Errors.id(_args.repayAssetAddr), Errors.id(_args.seizeAssetAddr));
        }

        /* ------------------------------- Charge fee ------------------------------- */
        handleMinterFee(repayAsset, _args.account, repayAmount, Enums.MinterFee.Close);

        /* -------------------------------- Liquidate ------------------------------- */
        LiquidateExecution memory params = LiquidateExecution(
            _args.account,
            repayAmount,
            fromWad(valueToAmount(repayValue, seizeAsset.price(), seizeAsset.liqIncentive), seizeAsset.decimals),
            _args.repayAssetAddr,
            _args.repayAssetIndex,
            _args.seizeAssetAddr,
            _args.seizeAssetIndex
        );
        uint256 seizedAmount = _liquidateAssets(seizeAsset, repayAsset, params);

        // Send liquidator the seized collateral.
        IERC20(_args.seizeAssetAddr).safeTransfer(msg.sender, seizedAmount);

        emit MEvent.LiquidationOccurred(
            _args.account,
            // solhint-disable-next-line avoid-tx-origin
            msg.sender,
            _args.repayAssetAddr,
            repayAmount,
            _args.seizeAssetAddr,
            seizedAmount
        );
    }

    /// @inheritdoc IMinterLiquidationFacet
    function getMaxLiqValue(
        address _account,
        address _repayAssetAddr,
        address _seizeAssetAddr
    ) external view returns (MaxLiqInfo memory) {
        Asset storage repayAsset = cs().onlyMinterMintable(_repayAssetAddr);
        Asset storage seizeAsset = cs().onlyMinterCollateral(_seizeAssetAddr);
        uint256 maxLiqValue = _getMaxLiqValue(_account, repayAsset, seizeAsset, _seizeAssetAddr);
        uint256 seizeAssetPrice = seizeAsset.price();
        uint256 repayAssetPrice = repayAsset.price();
        uint256 seizeAmount = fromWad(
            valueToAmount(maxLiqValue, seizeAssetPrice, seizeAsset.liqIncentive),
            seizeAsset.decimals
        );
        return
            MaxLiqInfo({
                account: _account,
                repayValue: maxLiqValue,
                repayAssetAddr: _repayAssetAddr,
                repayAmount: maxLiqValue.wadDiv(repayAssetPrice),
                repayAssetIndex: ms().mintedKreskoAssets[_account].find(_repayAssetAddr).index,
                repayAssetPrice: repayAssetPrice,
                seizeAssetAddr: _seizeAssetAddr,
                seizeAmount: seizeAmount,
                seizeValue: seizeAmount.wadMul(seizeAssetPrice),
                seizeAssetPrice: seizeAssetPrice,
                seizeAssetIndex: ms().depositedCollateralAssets[_account].find(_seizeAssetAddr).index
            });
    }

    function _liquidateAssets(
        Asset storage collateral,
        Asset storage krAsset,
        LiquidateExecution memory args
    ) internal returns (uint256 seizedAmount) {
        MinterState storage s = ms();

        /* -------------------------------------------------------------------------- */
        /*                                 Reduce debt                                */
        /* -------------------------------------------------------------------------- */
        s.kreskoAssetDebt[args.account][args.repayAssetAddr] -= IKreskoAssetIssuer(krAsset.anchor).destroy(
            args.repayAmount,
            msg.sender
        );

        // If the liquidation repays entire asset debt, remove from minted assets array.
        if (s.accountDebtAmount(args.account, args.repayAssetAddr, krAsset) == 0) {
            s.mintedKreskoAssets[args.account].removeAddress(args.repayAssetAddr, args.repayAssetIndex);
        }

        /* -------------------------------------------------------------------------- */
        /*                              Reduce collateral                             */
        /* -------------------------------------------------------------------------- */
        uint256 collateralDeposits = s.accountCollateralAmount(args.account, args.seizedAssetAddr, collateral);

        /* ------------------------ Above collateral deposits ----------------------- */

        if (collateralDeposits > args.seizeAmount) {
            uint256 newDepositAmount = collateralDeposits - args.seizeAmount;

            // *EDGE CASE*: If the collateral asset is also a kresko asset, ensure that collateral remains over minimum amount required.
            if (newDepositAmount < Constants.MIN_KRASSET_COLLATERAL_AMOUNT && collateral.isMinterMintable) {
                args.seizeAmount -= Constants.MIN_KRASSET_COLLATERAL_AMOUNT - newDepositAmount;
                newDepositAmount = Constants.MIN_KRASSET_COLLATERAL_AMOUNT;
            }

            s.collateralDeposits[args.account][args.seizedAssetAddr] = collateral.toNonRebasingAmount(newDepositAmount);
            return args.seizeAmount;
        } else if (collateralDeposits < args.seizeAmount) {
            revert Errors.LIQUIDATION_SEIZED_LESS_THAN_EXPECTED(
                Errors.id(args.repayAssetAddr),
                collateralDeposits,
                args.seizeAmount
            );
        }

        /* ------------------- Exact or below collateral deposits ------------------- */
        // Remove the collateral deposits.
        s.collateralDeposits[args.account][args.seizedAssetAddr] = 0;
        // Remove from the deposits array.
        s.depositedCollateralAssets[args.account].removeAddress(args.seizedAssetAddr, args.seizedAssetIndex);
        // Seized amount is the collateral deposits.
        return collateralDeposits;
    }

    function _getMaxLiqValue(
        address _account,
        Asset storage _repayAsset,
        Asset storage _seizeAsset,
        address _seizeAssetAddr
    ) internal view returns (uint256 maxValue) {
        uint32 maxLiquidationRatio = ms().maxLiquidationRatio;
        (uint256 totalCollateralValue, uint256 seizeAssetValue) = ms().accountTotalCollateralValue(_account, _seizeAssetAddr);

        return
            _calcMaxLiqValue(
                _repayAsset,
                _seizeAsset,
                ms().accountMinCollateralAtRatio(_account, maxLiquidationRatio),
                totalCollateralValue,
                seizeAssetValue,
                cs().minDebtValue,
                maxLiquidationRatio
            );
    }

    function _calcMaxLiqValue(
        Asset storage _repayAsset,
        Asset storage _seizeAsset,
        uint256 _minCollateralValue,
        uint256 _totalCollateralValue,
        uint256 _seizeAssetValue,
        uint96 _minDebtValue,
        uint32 _maxLiquidationRatio
    ) internal view returns (uint256) {
        if (!(_totalCollateralValue < _minCollateralValue)) return 0;
        // Calculate reduction percentage from seizing collateral
        uint256 seizeReductionPct = (_seizeAsset.liqIncentive + _repayAsset.closeFee).percentMul(_seizeAsset.factor);
        // Calculate adjusted seized asset value
        _seizeAssetValue = _seizeAssetValue.percentDiv(seizeReductionPct);
        // Substract reduction from increase to get liquidation factor
        uint256 liquidationFactor = _repayAsset.kFactor.percentMul(_maxLiquidationRatio) - seizeReductionPct;
        // Calculate maximum liquidation value
        uint256 maxLiquidationValue = (_minCollateralValue - _totalCollateralValue).percentDiv(liquidationFactor);
        // Clamped to minimum debt value
        if (_minDebtValue > maxLiquidationValue) return _minDebtValue;
        // Maximum value possible for the seize asset
        return maxLiquidationValue < _seizeAssetValue ? maxLiquidationValue : _seizeAssetValue;
    }
}
