// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Gate} from "../Gate.sol";
import {Factory} from "../Factory.sol";
import {ERC20Gate} from "./ERC20Gate.sol";
import {FullMath} from "../lib/FullMath.sol";

/// @title ERC4626Gate
/// @author zefram.eth
/// @notice The Gate implementation for ERC4626 vaults
contract ERC4626Gate is ERC20Gate {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Initialization
    /// -----------------------------------------------------------------------

    constructor(Factory factory_) ERC20Gate(factory_) {}

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    /// @inheritdoc Gate
    function getUnderlyingOfVault(address vault)
        public
        view
        virtual
        override
        returns (ERC20)
    {
        return ERC4626(vault).asset();
    }

    /// @inheritdoc Gate
    function getPricePerVaultShare(address vault)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return ERC4626(vault).convertToAssets(PRECISION);
    }

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    /// @inheritdoc Gate
    function _depositIntoVault(
        ERC20 underlying,
        uint256 underlyingAmount,
        address vault
    ) internal virtual override {
        if (underlying.allowance(address(this), vault) != 0) {
            // reset allowance to support tokens like USDT
            // that only allow non-zero approval if the current
            // allowance is zero
            underlying.safeApprove(vault, 0);
        }
        // we don't do infinite approval because vault is not trusted
        underlying.safeApprove(vault, underlyingAmount);

        ERC4626(vault).deposit(underlyingAmount, address(this));
    }

    /// @inheritdoc Gate
    function _withdrawFromVault(
        address recipient,
        address vault,
        uint256 underlyingAmount,
        uint256, /*pricePerVaultShare*/
        bool checkBalance
    ) internal virtual override returns (uint256 withdrawnUnderlyingAmount) {
        if (checkBalance) {
            uint256 sharesBalance = ERC4626(vault).balanceOf(address(this));
            uint256 sharesRequired = ERC4626(vault).previewWithdraw(
                underlyingAmount
            );
            if (sharesRequired > sharesBalance) {
                return
                    ERC4626(vault).redeem(
                        sharesBalance,
                        recipient,
                        address(this)
                    );
            }
        }

        // we know we have enough shares, use withdraw
        ERC4626(vault).withdraw(underlyingAmount, recipient, address(this));
        return underlyingAmount;
    }

    /// @inheritdoc Gate
    function _vaultSharesAmountToUnderlyingAmount(
        address vault,
        uint256 vaultSharesAmount,
        uint256 /*pricePerVaultShare*/
    ) internal view virtual override returns (uint256) {
        return ERC4626(vault).convertToAssets(vaultSharesAmount);
    }

    /// @inheritdoc Gate
    function _underlyingAmountToVaultSharesAmount(
        address vault,
        uint256 underlyingAmount,
        uint256 /*pricePerVaultShare*/
    ) internal view virtual override returns (uint256) {
        return ERC4626(vault).convertToShares(underlyingAmount);
    }
}
