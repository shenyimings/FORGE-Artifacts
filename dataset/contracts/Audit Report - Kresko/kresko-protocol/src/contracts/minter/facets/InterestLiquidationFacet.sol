// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IInterestLiquidationFacet} from "../interfaces/IInterestLiquidationFacet.sol";
import {Arrays} from "../../libs/Arrays.sol";
import {Error} from "../../libs/Errors.sol";
import {LibDecimals} from "../libs/LibDecimals.sol";
import {LibCalculation} from "../libs/LibCalculation.sol";
import {WadRay} from "../../libs/WadRay.sol";
import {MinterEvent, InterestRateEvent} from "../../libs/Events.sol";
import {SafeERC20, IERC20Permit} from "../../shared/SafeERC20.sol";
import {DiamondModifiers} from "../../diamond/DiamondModifiers.sol";
import {KrAsset, CollateralAsset} from "../MinterTypes.sol";
import {ms, MinterState} from "../MinterStorage.sol";
import {irs} from "../InterestRateState.sol";

/**
 * @author Kresko
 * @title InterestLiquidationFacet
 * @notice Main end-user functionality concerning liquidations of accrued KISS interest within the Kresko protocol
 */
contract InterestLiquidationFacet is DiamondModifiers, IInterestLiquidationFacet {
    using Arrays for address[];
    using LibDecimals for uint8;
    using LibDecimals for uint256;
    using WadRay for uint256;
    using SafeERC20 for IERC20Permit;

    /// @inheritdoc IInterestLiquidationFacet
    function batchLiquidateInterest(address _account, address _collateralAssetToSeize) external nonReentrant {
        // Borrower cannot liquidate themselves
        require(msg.sender != _account, Error.SELF_LIQUIDATION);
        // Check that this account is below its minimum collateralization ratio and can be liquidated.
        require(ms().isAccountLiquidatable(_account), Error.NOT_LIQUIDATABLE);
        // Collateral exists
        require(ms().collateralAssets[_collateralAssetToSeize].exists, Error.COLLATERAL_DOESNT_EXIST);

        address[] memory mintedKreskoAssets = ms().getMintedKreskoAssets(_account);

        // Loop all accounts minted assets and sum all accrued kiss interest
        uint256 kissAmountToRepay;
        for (uint256 i; i < mintedKreskoAssets.length; i++) {
            address repayKreskoAsset = mintedKreskoAssets[i];
            // Repays the full interest of this asset on behalf of the account being liquidated
            kissAmountToRepay += ms().repayFullStabilityRateInterest(_account, repayKreskoAsset);
            // If the liquidation repays the user's entire Kresko asset balance, remove it from minted assets array.
            if (ms().kreskoAssetDebt[_account][repayKreskoAsset] == 0) {
                ms().mintedKreskoAssets[_account].removeAddress(repayKreskoAsset, i);
            }
            // Check if the status with amount repaid is still underwater, if so no further liquidation is needed
            if (
                !ms().isAccountLiquidatable(
                    _account,
                    kissAmountToRepay.fromWadPriceToUint().wadMul(
                        ms().collateralAssets[_collateralAssetToSeize].liquidationIncentive
                    )
                )
            ) break;
        }

        // Emit a separate event for batch repayment itself
        emit InterestRateEvent.StabilityRateInterestBatchRepaid(_account, kissAmountToRepay);

        // Seize collateral and send to liquidator according to the repayment made
        uint256 collateralSeizeAmount = _seizeAndTransferCollateral(
            _account,
            _collateralAssetToSeize,
            ms().getDepositedCollateralAssetIndex(_account, _collateralAssetToSeize),
            kissAmountToRepay
        );

        emit MinterEvent.BatchInterestLiquidationOccurred(
            _account,
            msg.sender,
            _collateralAssetToSeize,
            kissAmountToRepay,
            collateralSeizeAmount
        );
    }

    /// @inheritdoc IInterestLiquidationFacet
    function liquidateInterest(
        address _account,
        address _repayKreskoAsset,
        address _collateralAssetToSeize
    ) external nonReentrant {
        // Borrower cannot liquidate themselves
        require(msg.sender != _account, Error.SELF_LIQUIDATION);
        // krAsset exists
        require(ms().kreskoAssets[_repayKreskoAsset].exists, Error.KRASSET_DOESNT_EXIST);
        // Check that this account is below its minimum collateralization ratio and can be liquidated.
        require(ms().isAccountLiquidatable(_account), Error.NOT_LIQUIDATABLE);
        // Collateral exists
        require(ms().collateralAssets[_collateralAssetToSeize].exists, Error.COLLATERAL_DOESNT_EXIST);

        // Repays the full interest of this asset on behalf of the account being liquidated
        uint256 kissRepayAmount = ms().repayFullStabilityRateInterest(_account, _repayKreskoAsset);

        uint256 mintedKreskoAssetIndex = ms().getMintedKreskoAssetsIndex(_account, _repayKreskoAsset);

        // Seize collateral and send to liquidator according to the repayment made
        uint256 collateralAmountSeized = _seizeAndTransferCollateral(
            _account,
            _collateralAssetToSeize,
            ms().getDepositedCollateralAssetIndex(_account, _collateralAssetToSeize),
            kissRepayAmount
        );

        // If the liquidation repays the user's entire Kresko asset balance, remove it from minted assets array.
        if (ms().kreskoAssetDebt[_account][_repayKreskoAsset] == 0) {
            ms().mintedKreskoAssets[_account].removeAddress(_repayKreskoAsset, mintedKreskoAssetIndex);
        }

        emit MinterEvent.InterestLiquidationOccurred(
            _account,
            msg.sender,
            _repayKreskoAsset,
            kissRepayAmount, // without the liquidation bonus
            _collateralAssetToSeize,
            collateralAmountSeized // with the liquidation bonus
        );
    }

    /**
     * @notice Internal function to perform collateral seizing when interest gets liquidated
     * @dev
     * @param _account Account being liquidated
     * @param _collateralAssetToSeize Collateral asset used to liquidate the debt
     * @param _depositedCollateralAssetIndex Deposit index for the liquidated accounts collateral
     * @param _kissRepayAmount Accrued KISS interest value being liquidated
     */
    function _seizeAndTransferCollateral(
        address _account,
        address _collateralAssetToSeize,
        uint256 _depositedCollateralAssetIndex,
        uint256 _kissRepayAmount
    ) internal returns (uint256 seizeAmount) {
        MinterState storage s = ms();

        seizeAmount = s.collateralAssets[_collateralAssetToSeize].decimals.fromWad(
            LibCalculation.calculateAmountToSeize(
                s.collateralAssets[_collateralAssetToSeize].liquidationIncentive,
                s.collateralAssets[_collateralAssetToSeize].uintAggregatePrice(s.oracleDeviationPct),
                _kissRepayAmount.fromWadPriceToUint()
            )
        );

        // Collateral deposits for the seized asset of the account being liquidated
        uint256 collateralDeposit = s.getCollateralDeposits(_account, _collateralAssetToSeize);

        // Default case where deposits are greater than the seized amount
        if (collateralDeposit > seizeAmount) {
            // Convert the value being seized into non-rebasing value
            s.collateralDeposits[_account][_collateralAssetToSeize] -= ms()
                .collateralAssets[_collateralAssetToSeize]
                .toNonRebasingAmount(seizeAmount);
        } else {
            // This clause means user either has collateralDeposits equal or less than the _seizeAmount
            seizeAmount = collateralDeposit;
            // So we set the collateralDeposits to 0
            s.collateralDeposits[_account][_collateralAssetToSeize] = 0;
            // And remove the asset from the deposits array.
            s.depositedCollateralAssets[_account].removeAddress(
                _collateralAssetToSeize,
                _depositedCollateralAssetIndex
            );
        }

        // Send liquidator the seized collateral.
        IERC20Permit(_collateralAssetToSeize).safeTransfer(msg.sender, seizeAmount);
    }
}
