// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

import {Role} from "../libs/Authorization.sol";

import {IKreskoAssetIssuer} from "./IKreskoAssetIssuer.sol";
import {IKreskoAssetAnchor} from "./IKreskoAssetAnchor.sol";
import {ERC4626Upgradeable, IKreskoAsset} from "./ERC4626Upgradeable.sol";
import {IERC165} from "../shared/IERC165.sol";

/* solhint-disable no-empty-blocks */

/**
 * @title Kresko Asset Anchor
 * Pro-rata representation of the underlying kresko asset.
 * Based on ERC-4626 by Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol)
 *
 * @notice Main purpose of this token is to represent a static amount of the possibly rebased underlying KreskoAsset.
 * Main use-cases are normalized book-keeping, bridging and integration with external contracts.
 *
 * @notice Shares means amount of this token.
 * @notice Assets mean amount of KreskoAssets.
 * @author Kresko
 */
contract KreskoAssetAnchor is ERC4626Upgradeable, IKreskoAssetAnchor, AccessControlEnumerableUpgradeable {
    /* -------------------------------------------------------------------------- */
    /*                                 Immutables                                 */
    /* -------------------------------------------------------------------------- */
    constructor(IKreskoAsset _asset) payable ERC4626Upgradeable(_asset) {}

    /// @inheritdoc IKreskoAssetAnchor
    function initialize(
        IKreskoAsset _asset,
        string memory _name,
        string memory _symbol,
        address _admin
    ) external initializer {
        // ERC4626
        __ERC4626Upgradeable_init(_asset, _name, _symbol);

        // This does nothing but doesn't hurt to make sure it's called
        __AccessControlEnumerable_init();

        // Default admin setup
        _setupRole(Role.DEFAULT_ADMIN, _admin);
        _setupRole(Role.ADMIN, _admin);

        _setupRole(Role.DEFAULT_ADMIN, msg.sender);
        _setupRole(Role.ADMIN, msg.sender);

        // Setup the operator, which is the protocol linked to the main asset
        _setupRole(Role.OPERATOR, asset.kresko());
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
        return
            interfaceId != 0xffffffff &&
            (interfaceId == type(IKreskoAssetAnchor).interfaceId ||
                interfaceId == type(IKreskoAssetIssuer).interfaceId ||
                interfaceId == 0x01ffc9a7 ||
                interfaceId == 0x36372b07 ||
                super.supportsInterface(interfaceId));
    }

    /// @inheritdoc IKreskoAssetAnchor
    function reinitializeERC20(
        string memory _name,
        string memory _symbol,
        uint8 _version
    ) external onlyRole(Role.ADMIN) reinitializer(_version) {
        __ERC20Upgradeable_init(_name, _symbol, decimals);
    }

    /// @inheritdoc IKreskoAssetAnchor
    function totalAssets() public view virtual override(IKreskoAssetAnchor, ERC4626Upgradeable) returns (uint256) {
        return asset.totalSupply();
    }

    /// @inheritdoc IKreskoAssetIssuer
    function convertToAssets(
        uint256 shares
    ) public view virtual override(ERC4626Upgradeable, IKreskoAssetIssuer) returns (uint256 assets) {
        return super.convertToAssets(shares);
    }

    /// @inheritdoc IKreskoAssetIssuer
    function convertToShares(
        uint256 assets
    ) public view virtual override(ERC4626Upgradeable, IKreskoAssetIssuer) returns (uint256 shares) {
        return super.convertToShares(assets);
    }

    /// @inheritdoc IKreskoAssetIssuer
    function issue(
        uint256 _assets,
        address _to
    ) public virtual override(ERC4626Upgradeable, IKreskoAssetIssuer) onlyRole(Role.OPERATOR) returns (uint256 shares) {
        shares = super.issue(_assets, _to);
    }

    /// @inheritdoc IKreskoAssetIssuer
    function destroy(
        uint256 _assets,
        address _from
    ) public virtual override(ERC4626Upgradeable, IKreskoAssetIssuer) onlyRole(Role.OPERATOR) returns (uint256 shares) {
        shares = super.destroy(_assets, _from);
    }

    /* -------------------------------------------------------------------------- */
    /*                            INTERNAL HOOKS LOGIC                            */
    /* -------------------------------------------------------------------------- */

    function _beforeWithdraw(uint256 assets, uint256 shares) internal virtual override {
        super._beforeWithdraw(assets, shares);
    }

    function _afterDeposit(uint256 assets, uint256 shares) internal virtual override {
        super._afterDeposit(assets, shares);
    }
}
