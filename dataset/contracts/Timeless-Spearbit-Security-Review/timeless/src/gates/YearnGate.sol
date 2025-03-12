// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Gate} from "../Gate.sol";
import {Factory} from "../Factory.sol";
import {ERC20Gate} from "./ERC20Gate.sol";
import {FullMath} from "../lib/FullMath.sol";
import {YearnVault} from "../external/YearnVault.sol";

/// @title YearnGate
/// @author zefram.eth
/// @notice The Gate implementation for Yearn vaults
contract YearnGate is ERC20Gate {
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
        return ERC20(YearnVault(vault).token());
    }

    /// @inheritdoc Gate
    function getPricePerVaultShare(address vault)
        public
        view
        virtual
        override
        returns (uint256)
    {
        YearnVault yearnVault = YearnVault(vault);
        return
            yearnVault.pricePerShare() *
            10**(PRECISION_DECIMALS - yearnVault.decimals());
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

        YearnVault(vault).deposit(underlyingAmount);
    }

    /// @inheritdoc Gate
    function _withdrawFromVault(
        address recipient,
        address vault,
        uint256 underlyingAmount,
        uint256 pricePerVaultShare,
        bool checkBalance
    ) internal virtual override returns (uint256 withdrawnUnderlyingAmount) {
        uint256 shareAmount = _underlyingAmountToVaultSharesAmount(
            vault,
            underlyingAmount,
            pricePerVaultShare
        );

        if (checkBalance) {
            uint256 shareBalance = getVaultShareBalance(vault);
            if (shareAmount > shareBalance) {
                // rounding error, withdraw entire balance
                shareAmount = shareBalance;
            }
        }

        withdrawnUnderlyingAmount = YearnVault(vault).withdraw(
            shareAmount,
            recipient
        );
    }

    /// @inheritdoc Gate
    function _vaultSharesAmountToUnderlyingAmount(
        address, /*vault*/
        uint256 vaultSharesAmount,
        uint256 pricePerVaultShare
    ) internal view virtual override returns (uint256) {
        return
            FullMath.mulDiv(vaultSharesAmount, pricePerVaultShare, PRECISION);
    }

    /// @inheritdoc Gate
    function _underlyingAmountToVaultSharesAmount(
        address, /*vault*/
        uint256 underlyingAmount,
        uint256 pricePerVaultShare
    ) internal view virtual override returns (uint256) {
        return FullMath.mulDiv(underlyingAmount, PRECISION, pricePerVaultShare);
    }
}
