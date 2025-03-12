// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {GlobalData} from "scdp/STypes.sol";

interface ISCDPStateFacet {
    /**
     * @notice Get the collateral pool deposit balance of `_account`. Including fees.
     * @param _account The account.
     * @param _depositAsset The deposit asset.
     */
    function getAccountScaledDepositsSCDP(address _account, address _depositAsset) external view returns (uint256);

    /**
     * @notice Get the total collateral principal deposits for `_account`
     * @param _account The account.
     * @param _depositAsset The deposit asset
     */
    function getAccountDepositSCDP(address _account, address _depositAsset) external view returns (uint256);

    function getAccountDepositFeesGainedSCDP(address _account, address _depositAsset) external view returns (uint256);

    /**
     * @notice Get the (principal) deposit value for `_account`
     * @param _account The account.
     * @param _depositAsset The deposit asset
     */
    function getAccountDepositValueSCDP(address _account, address _depositAsset) external view returns (uint256);

    /**
     * @notice Get the full value of account and fees for `_account`
     * @param _account The account.
     * @param _depositAsset The collateral asset
     */
    function getAccountScaledDepositValueCDP(address _account, address _depositAsset) external view returns (uint256);

    /**
     * @notice Get the total collateral deposit value for `_account`
     * @param _account The account.
     */
    function getAccountTotalDepositsValueSCDP(address _account) external view returns (uint256);

    /**
     * @notice Get the full value of account and fees for `_account`
     * @param _account The account.
     */
    function getAccountTotalScaledDepositsValueSCDP(address _account) external view returns (uint256);

    /**
     * @notice Get all pool CollateralAssets
     */
    function getDepositAssetsSCDP() external view returns (address[] memory);

    /**
     * @notice Get the total collateral deposits for `_collateralAsset`
     * @param _collateralAsset The collateral asset
     */
    function getDepositsSCDP(address _collateralAsset) external view returns (uint256);

    /**
     * @notice Get the total collateral swap deposits for `_collateralAsset`
     * @param _collateralAsset The collateral asset
     */
    function getSwapDepositsSCDP(address _collateralAsset) external view returns (uint256);

    /**
     * @notice Get the total collateral deposit value for `_collateralAsset`
     * @param _depositAsset The collateral asset
     * @param _ignoreFactors Ignore factors when calculating collateral and debt value.
     */
    function getCollateralValueSCDP(address _depositAsset, bool _ignoreFactors) external view returns (uint256);

    /**
     * @notice Get the total collateral value, oracle precision
     * @param _ignoreFactors Ignore factors when calculating collateral value.
     */
    function getTotalCollateralValueSCDP(bool _ignoreFactors) external view returns (uint256);

    /**
     * @notice Get all pool KreskoAssets
     */
    function getKreskoAssetsSCDP() external view returns (address[] memory);

    /**
     * @notice Get the collateral debt amount for `_krAsset`
     * @param _krAsset The KreskoAsset
     */
    function getDebtSCDP(address _krAsset) external view returns (uint256);

    /**
     * @notice Get the debt value for `_krAsset`
     * @param _krAsset The KreskoAsset
     * @param _ignoreFactors Ignore factors when calculating collateral and debt value.
     */
    function getDebtValueSCDP(address _krAsset, bool _ignoreFactors) external view returns (uint256);

    /**
     * @notice Get the total debt value of krAssets in oracle precision
     * @param _ignoreFactors Ignore factors when calculating debt value.
     */
    function getTotalDebtValueSCDP(bool _ignoreFactors) external view returns (uint256);

    /**
     * @notice Get enabled state of asset
     */
    function getAssetEnabledSCDP(address _assetAddr) external view returns (bool);

    /**
     * @notice Get whether swap is enabled from `_assetIn` to `_assetOut`
     * @param _assetIn The asset to swap from
     * @param _assetOut The asset to swap to
     */
    function getSwapEnabledSCDP(address _assetIn, address _assetOut) external view returns (bool);

    function getCollateralRatioSCDP() external view returns (uint256);

    /**
     * @notice Get pool collateral values and debt values with CR.
     * @return GlobalData struct
     */
    function getStatisticsSCDP() external view returns (GlobalData memory);
}
