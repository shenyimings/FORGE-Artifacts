// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {ISupplyVault} from "src/interfaces/extensions/ISupplyVault.sol";
import {IERC4626Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC4626Upgradeable.sol";

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ERC4626UpgradeableSafe, ERC4626Upgradeable, ERC20Upgradeable} from "@morpho-utils/ERC4626UpgradeableSafe.sol";

/// @title SupplyVault
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Aave V3.
/// @dev This vault is not fully compliant to EIP-4626 because `maxDeposit` & `maxMint` do not take into account the underlying market's pause status and AaveV3's supply cap.
/// Symmetrically, `maxWithdraw` & `maxRedeem` do not take into account the underlying market's pause status and liquidity.
contract SupplyVault is ISupplyVault, ERC4626UpgradeableSafe, Ownable2StepUpgradeable {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    /// @dev The main Morpho contract.
    IMorpho internal immutable _MORPHO;

    /* STORAGE */

    /// @dev The max iterations to use when this vault interacts with Morpho.
    uint96 internal _maxIterations;

    /// @dev The recipient of the rewards that will redistribute them to vault's users.
    address internal _recipient;

    /* CONSTRUCTOR */

    /// @dev Initializes network-wide immutables.
    /// @dev The implementation contract disables initialization upon deployment to avoid being hijacked.
    /// @param morpho The address of the main Morpho contract.
    constructor(address morpho) {
        if (morpho == address(0)) revert AddressIsZero();

        _disableInitializers();
        _MORPHO = IMorpho(morpho);
    }

    /* INITIALIZER */

    /// @dev Initializes the vault.
    /// @param newUnderlying The address of the underlying market to supply through this vault to Morpho.
    /// @param newRecipient The recipient to receive skimmed funds.
    /// @param name The name of the ERC20 token associated to this tokenized vault.
    /// @param symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    /// @param newMaxIterations The max iterations to use when this vault interacts with Morpho.
    function initialize(
        address newUnderlying,
        address newRecipient,
        string calldata name,
        string calldata symbol,
        uint256 initialDeposit,
        uint96 newMaxIterations
    ) external initializer {
        if (newUnderlying == address(0)) revert AddressIsZero();
        if (initialDeposit == 0) revert InitialDepositIsZero();

        _setRecipient(newRecipient);
        _setMaxIterations(newMaxIterations);

        ERC20(newUnderlying).safeApprove(address(_MORPHO), type(uint256).max);

        __Ownable_init_unchained(); // Equivalent to __Ownable2Step_init
        __ERC20_init_unchained(name, symbol);
        __ERC4626_init_unchained(ERC20Upgradeable(newUnderlying));
        __ERC4626UpgradeableSafe_init_unchained(initialDeposit, address(0xdead));
    }

    /* EXTERNAL */

    /// @notice Transfers the given ERC20 tokens to the vault recipient.
    /// @dev This is meant to be used to transfer rewards that are claimed to the vault or rescue tokens.
    ///      The vault is not intended to hold any ERC20 tokens between calls.
    function skim(address[] calldata tokens) external {
        address recipientMem = _recipient;
        if (recipientMem == address(0)) revert AddressIsZero();

        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = ERC20(token).balanceOf(address(this));
            ERC20(token).safeTransfer(recipientMem, amount);
            emit Skimmed(token, recipientMem, amount);
        }
    }

    /// @notice Sets the max iterations to use when this vault interacts with Morpho.
    function setMaxIterations(uint96 newMaxIterations) external onlyOwner {
        _setMaxIterations(newMaxIterations);
    }

    /// @notice Sets the recipient for the skim function.
    function setRecipient(address newRecipient) external onlyOwner {
        _setRecipient(newRecipient);
    }

    /// @notice The address of the Morpho contract this vault utilizes.
    function MORPHO() external view returns (IMorpho) {
        return _MORPHO;
    }

    /// @notice The recipient of any ERC20 tokens skimmed from this contract.
    function recipient() external view returns (address) {
        return _recipient;
    }

    /// @notice The max iterations to use when this vault interacts with Morpho.
    function maxIterations() external view returns (uint96) {
        return _maxIterations;
    }

    /* PUBLIC */

    /// @notice The amount of assets in the vault.
    function totalAssets() public view virtual override(IERC4626Upgradeable, ERC4626Upgradeable) returns (uint256) {
        return _MORPHO.supplyBalance(asset(), address(this));
    }

    /* INTERNAL */

    /// @dev Used in mint or deposit to deposit the underlying asset to Morpho.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        super._deposit(caller, receiver, assets, shares);
        _MORPHO.supply(asset(), assets, address(this), uint256(_maxIterations));
    }

    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Morpho.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        assets = _MORPHO.withdraw(asset(), assets, address(this), address(this), uint256(_maxIterations));
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /// @dev Sets the max iterations to use when this vault interacts with Morpho.
    function _setMaxIterations(uint96 newMaxIterations) internal {
        _maxIterations = newMaxIterations;
        emit MaxIterationsSet(newMaxIterations);
    }

    /// @dev Sets the recipient for the skim function.
    function _setRecipient(address newRecipient) internal {
        _recipient = newRecipient;
        emit RecipientSet(newRecipient);
    }

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[48] private __gap;
}
