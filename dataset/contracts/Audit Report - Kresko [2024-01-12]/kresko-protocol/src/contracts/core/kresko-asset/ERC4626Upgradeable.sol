// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20Permit} from "kresko-lib/token/IERC20Permit.sol";
import {SafeTransfer} from "kresko-lib/token/SafeTransfer.sol";
import {ERC20Upgradeable} from "kresko-lib/token/ERC20Upgradeable.sol";

import {FixedPointMath} from "libs/FixedPointMath.sol";
import {Errors} from "common/Errors.sol";

import {IKreskoAsset} from "./IKreskoAsset.sol";
import {IERC4626Upgradeable} from "./IERC4626Upgradeable.sol";

/* solhint-disable func-name-mixedcase */
/* solhint-disable no-empty-blocks */
/* solhint-disable func-visibility */

/// @notice Minimal ERC4626 tokenized Vault implementation.
/// @notice Kresko:
/// Adds issue/destroy functions that are called when KreskoAssets are minted/burned through the protocol.
/// @notice shares = anchor tokens
/// @notice assets = underlying KreskoAssets
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol)
/// @author Kresko (https://www.kresko.fi)
abstract contract ERC4626Upgradeable is IERC4626Upgradeable, ERC20Upgradeable {
    using SafeTransfer for IKreskoAsset;
    using FixedPointMath for uint256;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event Issue(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Destroy(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    /* -------------------------------------------------------------------------- */
    /*                                 Immutables                                 */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IERC4626Upgradeable
    IKreskoAsset public immutable asset;

    constructor(IKreskoAsset _asset) payable {
        asset = _asset;
    }

    /**
     * @notice Initializes the ERC4626.
     *
     * @param _asset The underlying (Kresko) Asset
     * @param _name Name of the anchor token
     * @param _symbol Symbol of the anchor token
     * @dev decimals are read from the underlying asset
     */
    function __ERC4626Upgradeable_init(
        IERC20Permit _asset,
        string memory _name,
        string memory _symbol
    ) internal onlyInitializing {
        __ERC20Upgradeable_init(_name, _symbol, _asset.decimals());
    }

    /* -------------------------------------------------------------------------- */
    /*                                Issue & Destroy                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice When new KreskoAssets are minted:
     * Issues the equivalent amount of anchor tokens to Kresko
     * Issues the equivalent amount of assets to user
     */
    function issue(uint256 assets, address to) public virtual returns (uint256 shares) {
        shares = convertToShares(assets);

        // Mint shares to kresko
        _mint(asset.kresko(), shares);
        // Mint assets to receiver
        asset.mint(to, assets);

        emit Issue(msg.sender, to, assets, shares);

        _afterDeposit(assets, shares);
    }

    /**
     * @notice When new KreskoAssets are burned:
     * Destroys the equivalent amount of anchor tokens from Kresko
     * Destroys the equivalent amount of assets from user
     */
    function destroy(uint256 assets, address from) public virtual returns (uint256 shares) {
        shares = convertToShares(assets);

        _beforeWithdraw(assets, shares);

        // Burn shares from kresko
        _burn(asset.kresko(), shares);
        // Burn assets from user
        asset.burn(from, assets);

        emit Destroy(msg.sender, from, from, assets, shares);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Accounting Logic                              */
    /* -------------------------------------------------------------------------- */

    function totalAssets() public view virtual returns (uint256);

    function convertToShares(uint256 assets) public view virtual returns (uint256 shares) {
        uint256 supply = _totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        shares = supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
        if (shares == 0) revert Errors.ZERO_SHARES_FROM_ASSETS(_assetId(), assets, _anchorId());
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256 assets) {
        uint256 supply = _totalSupply; // Saves an extra SLOAD if _totalSupply is non-zero.

        assets = supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
        if (assets == 0) revert Errors.ZERO_ASSETS_FROM_SHARES(_anchorId(), shares, _assetId());
    }

    /// @return shares for amount of @param assets
    function previewIssue(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    /// @return shares for amount of @param assets
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    /// @return assets for amount of @param shares
    function previewDestroy(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /// @return assets for amount of @param shares
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /// @return assets for amount of @param shares
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = _totalSupply; // Saves an extra SLOAD if _totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    /// @return shares for amount of @param assets
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = _totalSupply; // Saves an extra SLOAD if _totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    /* -------------------------------------------------------------------------- */
    /*                       DEPOSIT/WITHDRAWAL LIMIT VIEWS                       */
    /* -------------------------------------------------------------------------- */

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxIssue(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxDestroy(address owner) public view virtual returns (uint256) {
        return convertToAssets(_balances[owner]);
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(_balances[owner]);
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return _balances[owner];
    }

    /* -------------------------------------------------------------------------- */
    /*                               EXTERNAL USE                                 */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IERC4626Upgradeable
    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        shares = previewDeposit(assets);

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        _afterDeposit(assets, shares);
    }

    /// @inheritdoc IERC4626Upgradeable
    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                _allowances[owner][msg.sender] = allowed - shares;
            }
        }

        _beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /// @inheritdoc IERC4626Upgradeable
    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        _afterDeposit(assets, shares);
    }

    /// @inheritdoc IERC4626Upgradeable
    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                _allowances[owner][msg.sender] = allowed - shares;
            }
        }
        assets = previewRedeem(shares);

        _beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /* -------------------------------------------------------------------------- */
    /*                            INTERNAL HOOKS LOGIC                            */
    /* -------------------------------------------------------------------------- */

    function _anchorId() internal view returns (Errors.ID memory) {
        return Errors.ID(symbol, address(this));
    }

    function _assetId() internal view returns (Errors.ID memory) {
        return Errors.id(address(asset));
    }

    function _beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    function _afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}
