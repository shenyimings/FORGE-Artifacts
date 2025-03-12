// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {CollateralAsset, KrAsset, MinterParams} from "../MinterTypes.sol";

interface IStateFacet {
    /// @notice The EIP-712 typehash for the contract's domain.
    function domainSeparator() external view returns (bytes32);

    /// @notice amount of times the minter has been initialized
    function minterInitializations() external view returns (uint256);

    /// @notice The recipient of protocol fees.
    function feeRecipient() external view returns (address);

    /// @notice The AMM oracle address.
    function ammOracle() external view returns (address);

    /// @notice Offchain oracle decimals
    function extOracleDecimals() external view returns (uint8);

    /// @notice The collateralization ratio at which positions may be liquidated.
    function liquidationThreshold() external view returns (uint256);

    /// @notice The factor used to calculate the incentive a liquidator receives in the form of seized collateral.
    function liquidationIncentiveMultiplier() external view returns (uint256);

    /// @notice Multiplies max liquidatable value, allowing liquidations to go over LT.
    function maxLiquidationMultiplier() external view returns (uint256);

    /// @notice max deviation between main oracle and fallback oracle
    function oracleDeviationPct() external view returns (uint256);

    /// @notice The minimum ratio of collateral to debt that can be taken by direct action.
    function minimumCollateralizationRatio() external view returns (uint256);

    /// @notice The minimum USD value of an individual synthetic asset debt position.
    function minimumDebtValue() external view returns (uint256);

    /// @notice simple check if kresko asset exists
    function krAssetExists(address _krAsset) external view returns (bool);

    /**
     * @notice Get the state of a specific krAsset
     * @param _asset Address of the asset.
     * @return State of assets `KrAsset` struct
     */
    function kreskoAsset(address _asset) external view returns (KrAsset memory);

    /// @notice Mapping of collateral asset token address to information on the collateral asset.
    function collateralAsset(address _asset) external view returns (CollateralAsset memory);

    /// @notice simple check if collateral asset exists
    function collateralExists(address _collateralAsset) external view returns (bool);

    /// @notice get all meaningful protocol parameters
    function getAllParams() external view returns (MinterParams memory);

    /**
     * @notice Gets the USD value for a single collateral asset and amount.
     * @param _collateralAsset The address of the collateral asset.
     * @param _amount The amount of the collateral asset to calculate the value for.
     * @param _ignoreCollateralFactor Boolean indicating if the asset's collateral factor should be ignored.
     */
    function getCollateralValueAndOraclePrice(
        address _collateralAsset,
        uint256 _amount,
        bool _ignoreCollateralFactor
    ) external view returns (uint256, uint256);

    /**
     * @notice Gets the USD value for a single Kresko asset and amount.
     * @param _kreskoAsset The address of the Kresko asset.
     * @param _amount The amount of the Kresko asset to calculate the value for.
     * @param _ignoreKFactor Boolean indicating if the asset's k-factor should be ignored.
     * @return The value for the provided amount of the Kresko asset.
     */
    function getKrAssetValue(
        address _kreskoAsset,
        uint256 _amount,
        bool _ignoreKFactor
    ) external view returns (uint256);
}
