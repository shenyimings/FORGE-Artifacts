// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

// solhint-disable-next-line
import {AccessControlEnumerableUpgradeable, AccessControlUpgradeable} from "@oz-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {IAccessControl} from "@oz/access/IAccessControl.sol";
import {PausableUpgradeable} from "@oz-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "kresko-lib/token/ERC20Upgradeable.sol";
import {SafeTransfer} from "kresko-lib/token/SafeTransfer.sol";

import {Role} from "common/Constants.sol";
import {Errors} from "common/Errors.sol";
import {IKreskoAssetIssuer} from "kresko-asset/IKreskoAssetIssuer.sol";
import {IERC165} from "vendor/IERC165.sol";
import {IKISS} from "kiss/interfaces/IKISS.sol";
import {IVaultExtender} from "vault/interfaces/IVaultExtender.sol";
import {IVault} from "vault/interfaces/IVault.sol";

/* solhint-disable not-rely-on-time */

/**
 * @title Kresko Integrated Stable System
 * This is a non-rebasing Kresko Asset, intended to be paired with KreskoVault shares (vKISS) token.
 * @author Kresko
 */
contract KISS is IKISS, ERC20Upgradeable, PausableUpgradeable, AccessControlEnumerableUpgradeable {
    using SafeTransfer for ERC20Upgradeable;

    address public kresko;
    address public vKISS;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 dec_,
        address admin_,
        address kresko_,
        address vKISS_
    ) external initializer {
        if (kresko_.code.length == 0) revert Errors.NOT_A_CONTRACT(kresko_);

        __ERC20Upgradeable_init(name_, symbol_, dec_);

        // Setup the admin
        _grantRole(Role.DEFAULT_ADMIN, admin_);
        _grantRole(Role.ADMIN, admin_);

        // Setup the protocol
        kresko = kresko_;
        _grantRole(Role.OPERATOR, kresko_);

        // Setup vault
        vKISS = vKISS_;
    }

    modifier onlyContract() {
        if (msg.sender.code.length == 0) revert Errors.NOT_A_CONTRACT(msg.sender);
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Writes                                   */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IKISS
    function issue(uint256 _amount, address _to) public override onlyRole(Role.OPERATOR) returns (uint256) {
        _mint(_to, _amount);
        return _amount;
    }

    /// @inheritdoc IKISS
    function destroy(uint256 _amount, address _from) external onlyRole(Role.OPERATOR) returns (uint256) {
        _burn(_from, _amount);
        return _amount;
    }

    /// @inheritdoc IVaultExtender
    function vaultDeposit(
        address _assetAddr,
        uint256 _assets,
        address _receiver
    ) external returns (uint256 sharesOut, uint256 assetFee) {
        ERC20Upgradeable(_assetAddr).safeTransferFrom(msg.sender, address(this), _assets);
        (sharesOut, assetFee) = IVault(vKISS).deposit(_assetAddr, _assets, address(this));
        _mint(_receiver, sharesOut);
    }

    /// @inheritdoc IVaultExtender
    function vaultMint(
        address _assetAddr,
        uint256 _shares,
        address _receiver
    ) external returns (uint256 assetsIn, uint256 assetFee) {
        (assetsIn, assetFee) = IVault(vKISS).previewMint(_assetAddr, _shares);
        ERC20Upgradeable(_assetAddr).safeTransferFrom(msg.sender, address(this), assetsIn);
        IVault(vKISS).mint(_assetAddr, _shares, address(this));
        _mint(_receiver, _shares);
    }

    /// @inheritdoc IVaultExtender
    function vaultWithdraw(
        address _assetAddr,
        uint256 _assets,
        address _receiver,
        address _owner
    ) external returns (uint256 sharesIn, uint256 assetFee) {
        (sharesIn, assetFee) = IVault(vKISS).previewWithdraw(_assetAddr, _assets);
        withdrawFrom(_owner, address(this), sharesIn);
        IVault(vKISS).withdraw(_assetAddr, _assets, _receiver, address(this));
    }

    /// @inheritdoc IVaultExtender
    function vaultRedeem(
        address _assetAddr,
        uint256 _shares,
        address _receiver,
        address _owner
    ) external returns (uint256 assetsOut, uint256 assetFee) {
        withdrawFrom(_owner, address(this), _shares);
        (assetsOut, assetFee) = IVault(vKISS).redeem(_assetAddr, _shares, _receiver, address(this));
    }

    /// @inheritdoc IVaultExtender
    function deposit(uint256 _shares, address _receiver) external {
        ERC20Upgradeable(vKISS).transferFrom(msg.sender, address(this), _shares);
        _mint(_receiver, _shares);
    }

    /// @inheritdoc IVaultExtender
    function withdraw(uint256 _amount, address _receiver) external {
        _withdraw(msg.sender, _receiver, _amount);
    }

    /// @inheritdoc IVaultExtender
    function withdrawFrom(address _from, address _to, uint256 _amount) public {
        if (msg.sender != _from) {
            uint256 allowed = _allowances[_from][msg.sender]; // Saves gas for limited approvals.
            if (allowed != type(uint256).max) _allowances[_from][msg.sender] = allowed - _amount;
        }

        _withdraw(_from, _to, _amount);
    }

    /// @inheritdoc IKISS
    function pause() public onlyContract onlyRole(Role.ADMIN) {
        super._pause();
    }

    /// @inheritdoc IKISS
    function unpause() public onlyContract onlyRole(Role.ADMIN) {
        _unpause();
    }

    /// @inheritdoc IKISS
    function grantRole(
        bytes32 _role,
        address _to
    ) public override(IKISS, AccessControlUpgradeable, IAccessControl) onlyRole(Role.ADMIN) {
        if (_role == Role.OPERATOR && _to.code.length == 0) revert Errors.NOT_A_CONTRACT(_to);
        _grantRole(_role, _to);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Views                                   */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IKISS
    function exchangeRate() external view returns (uint256) {
        return IVault(vKISS).exchangeRate();
    }

    /// @inheritdoc IKreskoAssetIssuer
    function convertToShares(uint256 assets) external pure returns (uint256) {
        return assets;
    }

    /// @inheritdoc IKreskoAssetIssuer
    function convertManyToShares(uint256[] calldata assets) external pure returns (uint256[] calldata shares) {
        return assets;
    }

    /// @inheritdoc IKreskoAssetIssuer
    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    /// @inheritdoc IKreskoAssetIssuer
    function convertManyToAssets(uint256[] calldata shares) external pure returns (uint256[] calldata assets) {
        return shares;
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
        return (interfaceId != 0xffffffff &&
            (interfaceId == type(IKISS).interfaceId ||
                interfaceId == type(IKreskoAssetIssuer).interfaceId ||
                interfaceId == 0x01ffc9a7 ||
                interfaceId == 0x36372b07 ||
                super.supportsInterface(interfaceId)));
    }

    /* -------------------------------------------------------------------------- */
    /*                                  internal                                  */
    /* -------------------------------------------------------------------------- */
    function _withdraw(address from, address to, uint256 amount) internal {
        _burn(from, amount);
        ERC20Upgradeable(vKISS).transfer(to, amount);
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);
        if (paused()) revert Errors.PAUSED(address(this));
    }
}
