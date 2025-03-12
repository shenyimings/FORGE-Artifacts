// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {AccessControlEnumerableUpgradeable} from "@oz-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {IERC165} from "vendor/IERC165.sol";

import {Role} from "common/Constants.sol";
import {Errors} from "common/Errors.sol";
import {IKreskoAssetIssuer} from "./IKreskoAssetIssuer.sol";
import {IKreskoAssetAnchor} from "./IKreskoAssetAnchor.sol";
import {IERC4626Upgradeable} from "./IERC4626Upgradeable.sol";
import {ERC4626Upgradeable, IKreskoAsset} from "./ERC4626Upgradeable.sol";

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
    constructor(IKreskoAsset _asset) payable ERC4626Upgradeable(_asset) {
        // _disableInitializers();
    }

    /// @inheritdoc IKreskoAssetAnchor
    function initialize(IKreskoAsset _asset, string memory _name, string memory _symbol, address _admin) external initializer {
        // ERC4626
        __ERC4626Upgradeable_init(_asset, _name, _symbol);
        // Default admin setup
        _grantRole(Role.DEFAULT_ADMIN, _admin);
        _grantRole(Role.ADMIN, _admin);
        // Setup the operator, which is the protocol linked to the main asset
        _grantRole(Role.OPERATOR, asset.kresko());

        _asset.setAnchorToken(address(this));
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

    function convertManyToShares(uint256[] calldata assets) external view returns (uint256[] memory shares) {
        shares = new uint256[](assets.length);
        for (uint256 i; i < assets.length; ) {
            shares[i] = super.convertToShares(assets[i]);
            i++;
        }
        return shares;
    }

    /// @inheritdoc IKreskoAssetIssuer
    function convertManyToAssets(uint256[] calldata shares) external view returns (uint256[] memory assets) {
        assets = new uint256[](shares.length);
        for (uint256 i; i < shares.length; ) {
            assets[i] = super.convertToAssets(shares[i]);
            i++;
        }
        return assets;
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
    ) public virtual override(ERC4626Upgradeable, IKreskoAssetIssuer) returns (uint256 shares) {
        _onlyOperator();
        shares = super.issue(_assets, _to);
    }

    /// @inheritdoc IKreskoAssetIssuer
    function destroy(
        uint256 _assets,
        address _from
    ) public virtual override(ERC4626Upgradeable, IKreskoAssetIssuer) returns (uint256 shares) {
        _onlyOperator();
        shares = super.destroy(_assets, _from);
    }

    /// @inheritdoc IKreskoAssetAnchor
    function wrap(uint256 assets) external {
        _onlyOperatorOrAsset();
        // Mint anchor shares to the asset contract
        _mint(address(asset), convertToShares(assets));
    }

    /// @inheritdoc IKreskoAssetAnchor
    function unwrap(uint256 assets) external {
        _onlyOperatorOrAsset();
        // Burn anchor shares from the asset contract
        _burn(address(asset), convertToShares(assets));
    }

    /// @notice reverting function, kept to maintain compatibility with ERC4626 standard
    function deposit(uint256, address) public pure override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        revert Errors.DEPOSIT_NOT_SUPPORTED();
    }

    /// @notice reverting function, kept to maintain compatibility with ERC4626 standard
    function withdraw(
        uint256,
        address,
        address
    ) public pure override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        revert Errors.WITHDRAW_NOT_SUPPORTED();
    }

    /// @notice reverting function, kept to maintain compatibility with ERC4626 standard
    function redeem(uint256, address, address) public pure override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        revert Errors.REDEEM_NOT_SUPPORTED();
    }

    /* -------------------------------------------------------------------------- */
    /*                            INTERNAL HOOKS LOGIC                            */
    /* -------------------------------------------------------------------------- */
    function _onlyOperator() internal view {
        if (!hasRole(Role.OPERATOR, msg.sender)) {
            revert Errors.SENDER_NOT_OPERATOR(_anchorId(), msg.sender, asset.kresko());
        }
    }

    function _onlyOperatorOrAsset() private view {
        if (msg.sender != address(asset) && !hasRole(Role.OPERATOR, msg.sender)) {
            revert Errors.INVALID_KRASSET_OPERATOR(_assetId(), msg.sender, getRoleMember(Role.OPERATOR, 0));
        }
    }

    function _beforeWithdraw(uint256 assets, uint256 shares) internal virtual override {
        super._beforeWithdraw(assets, shares);
    }

    function _afterDeposit(uint256 assets, uint256 shares) internal virtual override {
        super._afterDeposit(assets, shares);
    }
}
