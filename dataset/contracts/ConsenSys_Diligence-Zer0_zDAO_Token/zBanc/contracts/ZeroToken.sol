// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626, ERC20, Math} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Permit, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {IZeroToken} from './IZeroToken.sol';

/**
 * @title ZeroToken
 * @dev ZeroToken contract. Enables entry and exit fees on an ERC4626 vault.
 * @custom:security-contact admin@zero.tech
 */
contract ZeroToken is IZeroToken, AccessControl, ERC4626, ERC20Permit, ERC20Votes {
    using Math for uint256;

    /// @notice Role definitions
    bytes32 private constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 private constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    /// @notice Thrown when the entry fee exceeds the limit.
    error EntryFeeExceedsLimit(uint256 entryFeeBasisPoints);

    /// @notice Thrown when the exit fee exceeds the limit.
    error ExitFeeExceedsLimit(uint256 exitFeeBasisPoints);

    /// @notice Thrown when a fee recipient is zero address.
    error NoRecipient();

    /// @notice Emitted when the contract is initialized.
    /// @param deployer The address of the contract deployer.
    /// @param name The name of the ERC20 token.
    /// @param symbol The symbol of the ERC20 token.
    /// @param reserveToken The ERC20 token used as the reserve asset.
    event ZeroTokenDeployed(
        address deployer,
        string name,
        string symbol,
        address reserveToken
    );

    /// @notice Emitted when the vault fees are set.
    /// @param entryFeeBasisPoints The new vault entry fee in basis points.
    /// @param exitFeeBasisPoints The new vault exit fee in basis points.
    event VaultFeesSet(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints);

    /// @notice Emitted when the protocol fees are set.
    /// @param entryFeeBasisPoints The new protocol entry fee in basis points.
    /// @param exitFeeBasisPoints The new protocol exit fee in basis points.
    event ProtocolFeesSet(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints);

    /// @notice Emitted when the creator fees are set.
    /// @param entryFeeBasisPoints The new creator entry fee in basis points.
    /// @param exitFeeBasisPoints The new creator exit fee in basis points.
    event CreatorFeesSet(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints);

    /// @notice Emitted when the vault fee recipient is set.
    /// @param recipient The new vault fee recipient.
    event VaultFeeRecipientSet(address recipient);

    /// @notice Emitted when the protocol fee recipient is set.
    /// @param recipient The new protocol fee recipient.
    event ProtocolFeeRecipientSet(address recipient);

    /// @notice Emitted when the creator fee recipient is set.
    /// @param recipient The new creator fee recipient.
    event CreatorFeeRecipientSet(address recipient);

    /// @notice The constant basis point used for fee calculations, equivalent to 10000.
    /// @dev This represents 100% in basis points, where 1 basis point is 0.01%.
    uint256 private constant BASIS = 1e4;

    /// @notice The entry fee basis points, paid to the vault.
    /// @dev This fee is applied when depositing and minting.
    uint256 private vaultEntryFee;

    /// @notice The exit fee basis points, paid to the vault.
    /// @dev This fee is applied when redeeming and withdrawing.
    uint256 private vaultExitFee;

    /// @notice The entry fee basis points, paid to protocol address.
    /// @dev This fee is applied when depositing and minting.
    uint256 private protocolEntryFee;

    /// @notice The exit fee basis points, paid to protocol address.
    /// @dev This fee is applied when redeeming and withdrawing.
    uint256 private protocolExitFee;

    /// @notice The entry fee basis points, paid to creator address.
    /// @dev This fee is applied when depositing and minting.
    uint256 private creatorEntryFee;

    /// @notice The exit fee basis points, paid to creator address.
    /// @dev This fee is applied when redeeming and withdrawing.
    uint256 private creatorExitFee;

    /// @notice The receiver of the protocol fees.
    /// @dev This recipient is paid during any deposit or withdraw.
    address private protocolFeeRecipient;

    /// @notice The receiver of the creator fees.
    /// @dev This recipient is paid during any deposit or withdraw.
    address private creatorFeeRecipient;

    /// @notice Initializes the contract with the given parameters and sets up the necessary roles.
    /// @param name The name of the ERC20 token.
    /// @param symbol The symbol of the ERC20 token.
    /// @param reserveToken The ERC20 token used as the reserve asset.
    /// @param vaultEntryFeeBps The vault entry fee in basis points.
    /// @param vaultExitFeeBps The vault exit fee in basis points.
    /// @param protocolEntryFeeBps The protocol entry fee in basis points.
    /// @param protocolExitFeeBps The protocol exit fee in basis points.
    /// @param creatorEntryFeeBps The creator entry fee in basis points.
    /// @param creatorExitFeeBps The creator exit fee in basis points.
    /// @param protocolAddress The protocol fee recipient address.
    /// @param adminAddress The default admin role address.
    constructor(
        string memory name,
        string memory symbol,
        IERC20 reserveToken,
        uint256 vaultEntryFeeBps,
        uint256 vaultExitFeeBps,
        uint256 protocolEntryFeeBps,
        uint256 protocolExitFeeBps,
        uint256 creatorEntryFeeBps,
        uint256 creatorExitFeeBps,
        address protocolAddress,
        address adminAddress
    )
        ERC4626(reserveToken)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(CREATOR_ROLE, msg.sender);
        _grantRole(PROTOCOL_ROLE, protocolAddress);

        // Set fees and recipients using internal functions without access modifiers
        _setVaultFees(vaultEntryFeeBps, vaultExitFeeBps);
        _setProtocolFees(protocolEntryFeeBps, protocolExitFeeBps);
        _setCreatorFees(creatorEntryFeeBps, creatorExitFeeBps);
        _setCreatorFeeRecipient(msg.sender);
        _setProtocolFeeRecipient(protocolAddress);

        emit ZeroTokenDeployed(msg.sender, name, symbol, address(reserveToken));
    }

    /// @notice Returns fee amounts and recipients.
    function getFeeData()
        public
        view
        override
        returns (
            uint256 entryFeeVault,
            uint256 exitFeeVault,
            uint256 entryFeeProtocol,
            uint256 exitFeeProtocol,
            uint256 entryFeeCreator,
            uint256 exitFeeCreator,
            address feeRecipientProtocol,
            address feeRecipientCreator
        )
    {
        return (
            vaultEntryFee,
            vaultExitFee,
            protocolEntryFee,
            protocolExitFee,
            creatorEntryFee,
            creatorExitFee,
            protocolFeeRecipient,
            creatorFeeRecipient
        );
    }

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     * Overridden with fee limiter.
     * @param owner The address to check for maximum withdraw.
     */
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        uint256 assets = _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
        return assets - _feeOnTotal(assets, vaultExitFee + creatorExitFee + protocolExitFee);
    }

    /**
     * @dev Previews the number of shares that would be minted for the given amount of assets,
     * after applying the entry fee.
     * @param assets The amount of assets to deposit.
     * @return shares The amount of shares that would be minted.
     */
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return super.previewDeposit(assets - _feeOnTotal(assets, vaultEntryFee + creatorEntryFee + protocolEntryFee));
    }

    /**
     * @dev Previews the amount of assets required to mint the given number of shares,
     * after applying the entry fee.
     * @param shares The amount of shares to mint.
     * @return assets The amount of assets required.
     */
    function previewMint(uint256 shares) public view override returns (uint256) {
        uint256 assets = super.previewMint(shares);
        return assets + _feeOnRaw(assets, vaultEntryFee + creatorEntryFee + protocolEntryFee);
    }

    /**
     * @dev Previews the number of assets that would be redeemed for the given amount of shares,
     * after applying the exit fee.
     * @param shares The amount of shares to redeem.
     * @return assets The amount of assets that would be redeemed.
     */
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 assets = super.previewRedeem(shares);
        return assets - _feeOnTotal(assets, vaultExitFee + creatorExitFee + protocolExitFee);
    }

    /**
     * @dev Previews the number of shares that would be burned for the given amount of assets withdrawn,
     * after applying the exit fee.
     * @param assets The amount of assets to withdraw.
     * @return shares The amount of shares that would be burned.
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return super.previewWithdraw(assets + _feeOnRaw(assets, vaultExitFee + creatorExitFee + protocolExitFee));
    }

    /// @dev Send entry fee to fee recipients. See {IERC4626-_deposit}.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        uint256 protocolFee = _feeOnTotal(assets, protocolEntryFee);
        uint256 creatorFee = _feeOnTotal(assets, creatorEntryFee);

        super._deposit(caller, receiver, assets, shares);

        if (protocolFee > 0) {
            SafeERC20.safeTransfer(IERC20(asset()), protocolFeeRecipient, protocolFee);
        }
        if (creatorFee > 0) {
            SafeERC20.safeTransfer(IERC20(asset()), creatorFeeRecipient, creatorFee);
        }
    }

    /// @dev Send exit fee to fee recipients. See {IERC4626-_withdraw}.
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        uint256 protocolFee = _feeOnRaw(assets, protocolExitFee);
        uint256 creatorFee = _feeOnRaw(assets, creatorExitFee);

        super._withdraw(caller, receiver, owner, assets, shares);

        if (protocolFee > 0 && protocolFeeRecipient != address(this)) {
            SafeERC20.safeTransfer(IERC20(asset()), protocolFeeRecipient, protocolFee);
        }
        if (creatorFee > 0 && creatorFeeRecipient != address(this)) {
            SafeERC20.safeTransfer(IERC20(asset()), creatorFeeRecipient, creatorFee);
        }
    }

    /// INTERNAL FUNCTIONS WITHOUT ACCESS MODIFIERS

    /// @dev Internal function to set vault fees without access control.
    function _setVaultFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints) internal {
        if (BASIS < entryFeeBasisPoints * 10) {
            revert EntryFeeExceedsLimit(entryFeeBasisPoints);
        }
        if (BASIS < exitFeeBasisPoints * 10) {
            revert ExitFeeExceedsLimit(exitFeeBasisPoints);
        }

        vaultEntryFee = entryFeeBasisPoints;
        vaultExitFee = exitFeeBasisPoints;

        emit VaultFeesSet(entryFeeBasisPoints, exitFeeBasisPoints);
    }

    /// @dev Internal function to set creator fees without access control.
    function _setCreatorFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints) internal {
        if (BASIS < entryFeeBasisPoints * 10) {
            revert EntryFeeExceedsLimit(entryFeeBasisPoints);
        }
        if (BASIS < exitFeeBasisPoints * 10) {
            revert ExitFeeExceedsLimit(exitFeeBasisPoints);
        }

        creatorEntryFee = entryFeeBasisPoints;
        creatorExitFee = exitFeeBasisPoints;

        emit CreatorFeesSet(creatorEntryFee, creatorExitFee);
    }

    /// @dev Internal function to set protocol fees without access control.
    function _setProtocolFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints) internal {
        if (BASIS < entryFeeBasisPoints * 10) {
            revert EntryFeeExceedsLimit(entryFeeBasisPoints);
        }
        if (BASIS < exitFeeBasisPoints * 10) {
            revert ExitFeeExceedsLimit(exitFeeBasisPoints);
        }

        protocolEntryFee = entryFeeBasisPoints;
        protocolExitFee = exitFeeBasisPoints;

        emit ProtocolFeesSet(protocolEntryFee, protocolExitFee);
    }

    /// @dev Internal function to set creator fee recipient without access control.
    function _setCreatorFeeRecipient(address newRecipient) internal {
        if (newRecipient == address(0)) {
            revert NoRecipient();
        }
        creatorFeeRecipient = newRecipient;

        _revokeRole(CREATOR_ROLE, creatorFeeRecipient);
        _grantRole(CREATOR_ROLE, newRecipient);

        emit CreatorFeeRecipientSet(newRecipient);
    }

    /// @dev Internal function to set protocol fee recipient without access control.
    function _setProtocolFeeRecipient(address newRecipient) internal {
        if (newRecipient == address(0)) {
            revert NoRecipient();
        }

        protocolFeeRecipient = newRecipient;
        
        _revokeRole(PROTOCOL_ROLE, protocolFeeRecipient);
        _grantRole(PROTOCOL_ROLE, newRecipient);
        
        emit ProtocolFeeRecipientSet(newRecipient);
    }

    /**
     * @dev Sets the vault fees.
     * @param entryFeeBasisPoints The new entry fee in basis points. Must not exceed 50%.
     * @param exitFeeBasisPoints The new exit fee in basis points. Must not exceed 50%.
     */
    function setVaultFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints)
        public
        override
        onlyRole(CREATOR_ROLE)
    {
        _setVaultFees(entryFeeBasisPoints, exitFeeBasisPoints);
    }

    /**
     * @dev Sets the creator fees.
     * @param entryFeeBasisPoints The new entry fee in basis points. Must not exceed 50%.
     * @param exitFeeBasisPoints The new exit fee in basis points. Must not exceed 50%.
     */
    function setCreatorFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints)
        public
        override
        onlyRole(CREATOR_ROLE)
    {
        _setCreatorFees(entryFeeBasisPoints, exitFeeBasisPoints);
    }

    /**
     * @dev Sets the creator fee recipient.
     * @param newRecipient The new creator fee recipient.
     */
    function setCreatorFeeRecipient(address newRecipient)
        public
        override
        onlyRole(CREATOR_ROLE)
    {
        _setCreatorFeeRecipient(newRecipient);
    }

    /**
     * @dev Sets the protocol fees.
     * @param entryFeeBasisPoints The new entry fee in basis points. Must not exceed 50%.
     * @param exitFeeBasisPoints The new exit fee in basis points. Must not exceed 50%.
     */
    function setProtocolFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints)
        public
        override
        onlyRole(PROTOCOL_ROLE)
    {
        _setProtocolFees(entryFeeBasisPoints, exitFeeBasisPoints);
    }

    /**
     * @dev Sets the protocol fee recipient.
     * @param newRecipient The new protocol fee recipient.
     */
    function setProtocolFeeRecipient(address newRecipient)
        public
        override
        onlyRole(PROTOCOL_ROLE)
    {
        _setProtocolFeeRecipient(newRecipient);
    }

    /// @dev Calculates the fees that should be added to an amount `assets` that does not already include fees.
    /// Used in {IERC4626-mint} and {IERC4626-withdraw} operations.
    function _feeOnRaw(uint256 assets, uint256 feeBasisPoints) private pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, BASIS, Math.Rounding.Ceil);
    }

    /// @dev Calculates the fee part of an amount `assets` that already includes fees.
    /// Used in {IERC4626-deposit} and {IERC4626-redeem} operations.
    function _feeOnTotal(uint256 assets, uint256 feeBasisPoints) private pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, feeBasisPoints + BASIS, Math.Rounding.Ceil);
    }

    /// @dev Decimal offset is increased from 0 to avoid inflation attack due to second round-in-favor-of-protocol introduced by fees
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return 1;
    }

    function decimals() public pure override(ERC20, ERC4626) returns (uint8) {
        return 18;
    }

    // Override required by Solidity for multiple inheritance
    function _update(address from, address to, uint256 amount) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    // Override required by Solidity for multiple inheritance
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    // Override supportsInterface to include AccessControl
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
