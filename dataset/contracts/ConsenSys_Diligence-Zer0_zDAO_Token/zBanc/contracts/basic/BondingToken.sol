// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;


import {IBondingToken} from './IBondingToken.sol';
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626, ERC20, Math} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BondingToken
 * @dev BondingToken contract. Enables entry and exit fees on an ERC4626 vault.
 * @custom:security-contact admin@zero.tech
 */
contract BondingToken is IBondingToken, Ownable, ERC4626 {
    using Math for uint256;

    /// @notice Thrown when the entry fee exceeds the limit.
    error EntryFeeExceedsLimit(uint256 entryFeeBasisPoints);

    /// @notice Thrown when the exit fee exceeds the limit.
    error ExitFeeExceedsLimit(uint256 exitFeeBasisPoints);

    /// @notice Emitted when the contract is initialized.
    /// @param deployer The address of the contract deployer
    /// @param name The name of the ERC20 token.
    /// @param symbol The symbol of the ERC20 token.
    /// @param reserveToken The ERC20 token used as the reserve asset.
    event BondingTokenDeployed(
        address deployer,
        string name,
        string symbol,
        address reserveToken
    );

    /// @notice Emitted when the entry fee is set.
    /// @param entryFeeBasisPoints The new entry fee in basis points.
    event EntryFeeSet(uint256 entryFeeBasisPoints);

    /// @notice Emitted when the exit fee is set.
    /// @param exitFeeBasisPoints The new exit fee in basis points.
    event ExitFeeSet(uint256 exitFeeBasisPoints);

    /// @notice Emitted when the entry fee recipient is set.
    /// @param recipient The new entry fee recipient.
    event EntryFeeRecipientSet(address recipient);

    /// @notice Emitted when the exit fee recipient is set.
    /// @param recipient The new exit fee recipient.
    event ExitFeeRecipientSet(address recipient);

    /// @notice The constant basis point used for fee calculations, equivalent to 10000.
    /// @dev This represents 100% in basis points, where 1 basis point is 0.01%.
    uint256 public constant BASIS = 1e4;

    /// @notice The entry fee basis points.
    /// @dev This fee is applied when depositing and minting.
    uint256 public entryFee;

    /// @notice The exit fee basis points.
    /// @dev This fee is applied when redeeming and withdrawing.
    uint256 public exitFee;

    /// @notice The receiver of the entry fees
    /// @dev This recipient is paid when depositing and minting.
    address public entryFeeRecipient;

    /// @notice The receiver of the exit fees
    /// @dev This recipient is paid when depositing and minting.
    address public exitFeeRecipient;

    /// @notice Initializes the contract with the given parameters and sets up the necessary inheritance.
    /// @param name The name of the ERC20 token.
    /// @param symbol The symbol of the ERC20 token.
    /// @param reserveToken The ERC20 token used as the reserve asset.
    /// @param entryFeeBasisPoints The entry fee in basis points (1 basis point = 0.01%).
    /// @param exitFeeBasisPoints The exit fee in basis points (1 basis point = 0.01%).
    /// @dev This constructor initializes the contract by setting the entry and exit fees.
    constructor(
        string memory name,
        string memory symbol,
        IERC20 reserveToken,
        uint256 entryFeeBasisPoints,
        uint256 exitFeeBasisPoints
    ) 
        Ownable(msg.sender)
        ERC4626(reserveToken)
        ERC20(name, symbol)
    {
        setEntryFee(entryFeeBasisPoints);
        setExitFee(exitFeeBasisPoints);
        emit BondingTokenDeployed(msg.sender, name, symbol, address(reserveToken));
    }

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call. 
     * Overriden with fee limiter.
     * @param owner The address to check for maximum withdraw
     */ 
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        uint assets = _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
        return assets - _feeOnTotal(assets, exitFee);
    }

    /**
     * @dev Previews the number of shares that would be minted for the given amount of assets,
     * after applying the entry fee.
     * @param assets The amount of assets to deposit.
     * @return shares The amount of shares that would be minted.
     */
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return super.previewDeposit(assets - _feeOnTotal(assets, entryFee));
    }

    /**
     * @dev Previews the amount of assets required to mint the given number of shares,
     * after applying the entry fee.
     * @param shares The amount of shares to mint.
     * @return assets The amount of assets required.
     */
    function previewMint(uint256 shares) public view override returns (uint256) {
        uint256 assets = super.previewMint(shares);
        return assets + _feeOnRaw(assets, entryFee);
    }

    /**
     * @dev Previews the number of assets that would be redeemed for the given amount of shares,
     * after applying the exit fee.
     * @param shares The amount of shares to redeem.
     * @return assets The amount of assets that would be redeemed.
     */
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 assets = super.previewRedeem(shares);
        return assets - _feeOnTotal(assets, exitFee);
    }

    /**
     * @dev Previews the number of shares that would be burned for the given amount of assets withdrawn,
     * after applying the exit fee.
     * @param assets The amount of assets to withdraw.
     * @return shares The amount of shares that would be burned.
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return super.previewWithdraw(assets + _feeOnRaw(assets, exitFee));
    }

    /**
     * @dev Sets the entry fee.
     * @param entryFeeBasisPoints The new entry fee in basis points. Must not exceed 50%.
     */
    function setEntryFee(uint256 entryFeeBasisPoints) public override onlyOwner {
        if (BASIS < entryFeeBasisPoints * 2) {
            revert EntryFeeExceedsLimit(entryFeeBasisPoints);
        }
        entryFee = entryFeeBasisPoints;
        emit EntryFeeSet(entryFeeBasisPoints);
    }

    /**
     * @dev Sets the exit fee.
     * @param exitFeeBasisPoints The new exit fee in basis points. Must not exceed 50%.
     */
    function setExitFee(uint256 exitFeeBasisPoints) public override onlyOwner {
        if (BASIS < exitFeeBasisPoints * 2) {
            revert ExitFeeExceedsLimit(exitFeeBasisPoints);
        }
        exitFee = exitFeeBasisPoints;
        emit ExitFeeSet(exitFeeBasisPoints);
    }

    /**
     * @dev Sets the entry fee recipient.
     * @param newRecipient The new entry fee recipient.
     */
    function setEntryFeeRecipient(address newRecipient) public onlyOwner {
        entryFeeRecipient = newRecipient;
        emit EntryFeeRecipientSet(newRecipient);
    }

    /**
     * @dev Sets the exit fee recipient.
     * @param newRecipient The new exit fee recipient.
     */
    function setExitFeeRecipient(address newRecipient) public onlyOwner {
        exitFeeRecipient = newRecipient;
        emit ExitFeeRecipientSet(newRecipient);
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
}