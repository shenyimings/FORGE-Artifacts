// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IAssetGroupRegistry.sol";
import "../access/Roles.sol";
import "../access/SpoolAccessControllable.sol";

/* ========== CONTRACTS ========== */

contract AssetGroupRegistry is IAssetGroupRegistry, SpoolAccessControllable, Initializable {
    /* ========== STATE VARIABLES ========== */

    /**
     * @notice Which are allowed to be used as an assets.
     * @dev token address => is allowed
     */
    mapping(address => bool) private _assetAllowlist;

    /**
     * @notice Asset groups registered in the system.
     */
    address[][] private _assetGroups;

    /**
     * @notice Hashes of registered asset groups.
     * @dev asset group hash => asset group ID
     */
    mapping(bytes32 => uint256) private _assetGroupHashes;

    /* ========== CONSTRUCTOR ========== */

    constructor(ISpoolAccessControl accessControl_) SpoolAccessControllable(accessControl_) {}

    function initialize(address[] calldata allowedTokens_) external initializer {
        for (uint256 i; i < allowedTokens_.length; ++i) {
            _allowToken(allowedTokens_[i]);
        }

        // asset group IDs start at 1, so we push dummy asset group
        _assetGroups.push(new address[](0));
    }

    /* ========== EXTERNAL VIEW FUNCTIONS ========== */

    function isTokenAllowed(address token) external view returns (bool) {
        return _assetAllowlist[token];
    }

    function numberOfAssetGroups() external view returns (uint256) {
        return _assetGroups.length - 1;
    }

    function listAssetGroup(uint256 assetGroupId)
        external
        view
        validAssetGroup(assetGroupId)
        returns (address[] memory)
    {
        return _assetGroups[assetGroupId];
    }

    function assetGroupLength(uint256 assetGroupId) external view validAssetGroup(assetGroupId) returns (uint256) {
        return _assetGroups[assetGroupId].length;
    }

    function validateAssetGroup(uint256 assetGroupId) external view {
        _checkIsValidAssetGroup(assetGroupId);
    }

    function checkAssetGroupExists(address[] calldata assets) external view returns (uint256) {
        return _findAssetGroup(assets);
    }

    /* ========== EXTERNAL MUTATIVE FUNCTIONS ========== */

    function allowToken(address token) external onlyRole(ROLE_SPOOL_ADMIN, msg.sender) {
        _allowToken(token);
    }

    function allowTokenBatch(address[] calldata tokens) external onlyRole(ROLE_SPOOL_ADMIN, msg.sender) {
        for (uint256 i; i < tokens.length; ++i) {
            _allowToken(tokens[i]);
        }
    }

    function registerAssetGroup(address[] calldata assets)
        external
        onlyRole(ROLE_SPOOL_ADMIN, msg.sender)
        returns (uint256)
    {
        if (assets.length == 0) {
            revert NoAssetsProvided();
        }

        for (uint256 i; i < assets.length; ++i) {
            if (i > 0 && assets[i] <= assets[i - 1]) {
                revert UnsortedArray();
            }

            if (!_assetAllowlist[assets[i]]) {
                revert TokenNotAllowed(assets[i]);
            }
        }

        bytes32 assetGroupHash = keccak256(abi.encode(assets));
        if (_assetGroupHashes[assetGroupHash] > 0) {
            revert AssetGroupAlreadyExists(_assetGroupHashes[assetGroupHash]);
        }

        _assetGroups.push(assets);

        uint256 assetGroupId = _assetGroups.length - 1;
        _assetGroupHashes[assetGroupHash] = assetGroupId;

        emit AssetGroupRegistered(assetGroupId);

        return assetGroupId;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Adds token to the asset allowlist.
     * Emits TokenAllowed event.
     */
    function _allowToken(address token) private {
        _assetAllowlist[token] = true;

        emit TokenAllowed(token);
    }

    /**
     * @dev Finds asset group composed of assets, if such a group exists.
     * @param assets Assets composing the asset group.
     * @return Asset group ID if such asset group exists, 0 otherwise.
     */
    function _findAssetGroup(address[] calldata assets) private view returns (uint256) {
        return _assetGroupHashes[keccak256(abi.encode(assets))];
    }

    /**
     * @dev Checks if asset group ID is valid.
     * Reverts if provided asset group ID does not belong to any asset group.
     */
    function _checkIsValidAssetGroup(uint256 assetGroupId) private view {
        if (assetGroupId == 0 || assetGroupId >= _assetGroups.length) {
            revert InvalidAssetGroup(assetGroupId);
        }
    }

    /* ========== MODIFIERS ========== */

    /**
     * @dev Only allows valid asset group IDs.
     */
    modifier validAssetGroup(uint256 assetGroupId) {
        _checkIsValidAssetGroup(assetGroupId);
        _;
    }
}
