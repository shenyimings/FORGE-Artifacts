// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MinterParams} from "minter/MTypes.sol";

interface IMinterStateFacet {
    /// @notice The collateralization ratio at which positions may be liquidated.
    function getLiquidationThresholdMinter() external view returns (uint32);

    /// @notice Multiplies max liquidation multiplier, if a full liquidation happens this is the resulting CR.
    function getMaxLiquidationRatioMinter() external view returns (uint32);

    /// @notice The minimum ratio of collateral to debt that can be taken by direct action.
    function getMinCollateralRatioMinter() external view returns (uint32);

    /// @notice simple check if kresko asset exists
    function getKrAssetExists(address _krAsset) external view returns (bool);

    /// @notice simple check if collateral asset exists
    function getCollateralExists(address _collateralAsset) external view returns (bool);

    /// @notice get all meaningful protocol parameters
    function getParametersMinter() external view returns (MinterParams memory);

    /**
     * @notice Gets the USD value for a single collateral asset and amount.
     * @param _collateralAsset The address of the collateral asset.
     * @param _amount The amount of the collateral asset to calculate the value for.
     * @return value The unadjusted value for the provided amount of the collateral asset.
     * @return adjustedValue The (cFactor) adjusted value for the provided amount of the collateral asset.
     * @return price The price of the collateral asset.
     */
    function getCollateralValueWithPrice(
        address _collateralAsset,
        uint256 _amount
    ) external view returns (uint256 value, uint256 adjustedValue, uint256 price);

    /**
     * @notice Gets the USD value for a single Kresko asset and amount.
     * @param _krAsset The address of the Kresko asset.
     * @param _amount The amount of the Kresko asset to calculate the value for.
     * @return value The unadjusted value for the provided amount of the debt asset.
     * @return adjustedValue The (kFactor) adjusted value for the provided amount of the debt asset.
     * @return price The price of the debt asset.
     */
    function getDebtValueWithPrice(
        address _krAsset,
        uint256 _amount
    ) external view returns (uint256 value, uint256 adjustedValue, uint256 price);
}
