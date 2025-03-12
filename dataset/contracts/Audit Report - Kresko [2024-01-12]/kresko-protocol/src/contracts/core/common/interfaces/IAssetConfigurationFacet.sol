// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {Asset} from "common/Types.sol";
import {Enums} from "common/Constants.sol";

interface IAssetConfigurationFacet {
    /**
     * @notice Adds a new asset to the common state.
     * @notice Performs validations according to the `_config` provided.
     * @dev Use validateAssetConfig / static call this for validation.
     * @param _assetAddr Asset address.
     * @param _config Configuration struct to save for the asset.
     * @param _feeds Feed addresses, if both are address(0) they are ignored.
     * @return Asset Result of addAsset.
     * @custom:signature addAsset(address,(bytes32,address,,uint16,uint16,uint16,uint16,uint16,uint256,uint256,uint256,uint128,uint16,uint16,uint16,uint16,uint8,bool,bool,bool,bool,bool,bool),address[2])
     * @custom:selector 0x73320167
     */
    function addAsset(address _assetAddr, Asset memory _config, address[2] memory _feeds) external returns (Asset memory);

    /**
     * @notice Update asset config.
     * @notice Performs validations according to the `_config` set.
     * @dev Use validateAssetConfig / static call this for validation.
     * @param _assetAddr The asset address.
     * @param _config Configuration struct to apply for the asset.
     * @custom:signature updateAsset(address,(bytes32,address,,uint16,uint16,uint16,uint16,uint16,uint256,uint256,uint256,uint128,uint16,uint16,uint16,uint16,uint8,bool,bool,bool,bool,bool,bool))
     * @custom:selector 0xe2f08b19
     */
    function updateAsset(address _assetAddr, Asset memory _config) external returns (Asset memory);

    /**
     * @notice  Updates the cFactor of a KreskoAsset. Convenience.
     * @param _assetAddr The collateral asset.
     * @param _newFactor The new collateral factor.
     */
    function setAssetCFactor(address _assetAddr, uint16 _newFactor) external;

    /**
     * @notice Updates the kFactor of a KreskoAsset.
     * @param _assetAddr The KreskoAsset.
     * @param _newKFactor The new kFactor.
     */
    function setAssetKFactor(address _assetAddr, uint16 _newKFactor) external;

    /**
     * @notice Validate supplied asset config. Reverts with information if invalid.
     * @param _assetAddr The asset address.
     * @param _config Configuration for the asset.
     * @return bool True for convenience.
     * @custom:signature validateAssetConfig(address,(bytes32,address,uint8[2],uint16,uint16,uint16,uint16,uint16,uint256,uint256,uint256,uint128,uint16,uint16,uint16,uint16,uint8,bool,bool,bool,bool,bool,bool))
     * @custom:selector 0xcadd46b6
     */
    function validateAssetConfig(address _assetAddr, Asset memory _config) external view returns (bool);

    /**
     * @notice Update oracle order for an asset.
     * @param _assetAddr The asset address.
     * @param _newOracleOrder List of 2 OracleTypes. 0 is primary and 1 is the reference.
     * @custom:signature setAssetOracleOrder(address,uint8[2])
     * @custom:selector 0x67029b02
     */
    function setAssetOracleOrder(address _assetAddr, Enums.OracleType[2] memory _newOracleOrder) external;
}
