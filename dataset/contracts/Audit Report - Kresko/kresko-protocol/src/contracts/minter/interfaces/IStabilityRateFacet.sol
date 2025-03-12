// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {StabilityRateParams} from "../facets/StabilityRateFacet.sol";
import {StabilityRateConfig} from "../InterestRateState.sol";

interface IStabilityRateFacet {
    /**
     * @notice Initialize an asset with stability rate setup values
     * @param _asset asset to setup
     * @param _setup setup parameters
     */
    function setupStabilityRateParams(address _asset, StabilityRateParams memory _setup) external;

    /**
     * @notice Configure existing stability rate values
     * @param _asset asset to configure
     * @param _setup setup parameters
     */
    function updateStabilityRateParams(address _asset, StabilityRateParams memory _setup) external;

    /// @notice Updates the debt index and stability rates for an asset
    /// @param _asset asset to update rate and index for
    function updateStabilityRateAndIndexForAsset(address _asset) external;

    /**
     * @notice Sets the protocol AMM oracle address
     * @param _kiss  The address of the oracle
     */
    function updateKiss(address _kiss) external;

    /**
     * @notice Repays part of accrued stability rate interest for a single asset
     * @param _account Account to repay interest for
     * @param _kreskoAsset Kresko asset to repay interest for
     * @param _kissRepayAmount USD value to repay (KISS)
     */
    function repayStabilityRateInterestPartial(
        address _account,
        address _kreskoAsset,
        uint256 _kissRepayAmount
    ) external;

    /**
     * @notice Repays accrued stability rate interest for a single asset
     * @param _account Account to repay interest for
     * @param _kreskoAsset Kresko asset to repay interest for
     * @return kissRepayAmount KISS value repaid
     */
    function repayFullStabilityRateInterest(
        address _account,
        address _kreskoAsset
    ) external returns (uint256 kissRepayAmount);

    /**
     * @notice Repays all accrued stability rate interest for an account
     * @param _account Account to repay all asset interests for
     * @return kissRepayAmount KISS value repaid
     */
    function batchRepayFullStabilityRateInterest(address _account) external returns (uint256 kissRepayAmount);

    /**
     * @notice Gets the current stability rate for an asset
     * @param _asset asset to get the stability rate for
     * @return stabilityRate the return variables of a contractâ€™s function state variable
     * @dev expressed in ray
     */
    function getStabilityRateForAsset(address _asset) external view returns (uint256 stabilityRate);

    /**
     * @notice Gets the current price rate (difference between AMM <-> Oracle pricing)
     * for an asset
     * @param _asset asset to get the rate for
     * @return priceRate the current
     * @dev expressed in ray
     */
    function getPriceRateForAsset(address _asset) external view returns (uint256 priceRate);

    /**
     * @notice Gets the current running debt index
     * @param _asset asset to get the index for
     * @return debtIndex current running debt index
     * @dev expressed in ray
     */
    function getDebtIndexForAsset(address _asset) external view returns (uint256 debtIndex);

    /**
     * @notice View stability rate configuration for an asset
     * @param _asset asset to view configuration for
     */
    function getStabilityRateConfigurationForAsset(address _asset) external view returns (StabilityRateConfig memory);

    /**
     * @notice The configured address of KISS
     */
    function kiss() external view returns (address);

    /**
     * @notice Get user stability rate data for an asset
     * @param _account asset to view configuration for
     * @param _asset asset to view configuration for
     * @return lastDebtIndex the previous debt index for the user
     */
    function getLastDebtIndexForAccount(address _account, address _asset) external view returns (uint128 lastDebtIndex);
}
