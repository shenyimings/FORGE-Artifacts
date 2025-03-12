// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IAccessControlEnumerable} from "@oz/access/extensions/IAccessControlEnumerable.sol";
import {IERC165} from "vendor/IERC165.sol";
import {IERC20Permit} from "kresko-lib/token/IERC20Permit.sol";

import {IKreskoAssetIssuer} from "./IKreskoAssetIssuer.sol";
import {IKreskoAsset} from "./IKreskoAsset.sol";
import {IERC4626Upgradeable} from "./IERC4626Upgradeable.sol";

interface IKreskoAssetAnchor is IKreskoAssetIssuer, IERC4626Upgradeable, IERC20Permit, IAccessControlEnumerable, IERC165 {
    function totalAssets() external view override(IERC4626Upgradeable) returns (uint256);

    /**
     * @notice Initializes the Kresko Asset Anchor.
     *
     * @param _asset The underlying (Kresko) Asset
     * @param _name Name of the anchor token
     * @param _symbol Symbol of the anchor token
     * @param _admin The adminstrator of this contract.
     * @dev Decimals are not supplied as they are read from the underlying Kresko Asset
     */
    function initialize(IKreskoAsset _asset, string memory _name, string memory _symbol, address _admin) external;

    /**
     * @notice Updates ERC20 metadata for the token in case eg. a ticker change
     * @param _name new name for the asset
     * @param _symbol new symbol for the asset
     * @param _version number that must be greater than latest emitted `Initialized` version
     */
    function reinitializeERC20(string memory _name, string memory _symbol, uint8 _version) external;

    /**
     * @notice Mint Kresko Anchor Asset to Kresko Asset (Only KreskoAsset can call)
     * @param assets The assets (uint256).
     */
    function wrap(uint256 assets) external;

    /**
     * @notice Burn Kresko Anchor Asset to Kresko Asset (Only KreskoAsset can call)
     * @param assets The assets (uint256).
     */
    function unwrap(uint256 assets) external;
}
