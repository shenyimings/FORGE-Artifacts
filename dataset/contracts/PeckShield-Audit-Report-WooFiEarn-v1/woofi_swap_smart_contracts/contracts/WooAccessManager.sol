// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/*

░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝

*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import './interfaces/IWooAccessManager.sol';

contract WooAccessManager is IWooAccessManager, Ownable, Pausable {
    /* ----- State variables ----- */

    mapping(address => bool) public override isFeeAdmin;
    mapping(address => bool) public override isVaultAdmin;
    mapping(address => bool) public override isRebateAdmin;
    mapping(address => bool) public override isZeroFeeVault;

    /* ----- Admin Functions ----- */

    /// @inheritdoc IWooAccessManager
    function setFeeAdmin(address feeAdmin, bool flag) external override onlyOwner whenNotPaused {
        require(feeAdmin != address(0), 'WooAccessManager: feeAdmin_ZERO_ADDR');
        isFeeAdmin[feeAdmin] = flag;
        emit FeeAdminUpdated(feeAdmin, flag);
    }

    /// @inheritdoc IWooAccessManager
    function batchSetFeeAdmin(address[] calldata feeAdmins, bool[] calldata flags)
        external
        override
        onlyOwner
        whenNotPaused
    {
        require(feeAdmins.length == flags.length, 'WooAccessManager: length_INVALID');

        for (uint256 i = 0; i < feeAdmins.length; i++) {
            require(feeAdmins[i] != address(0), 'WooAccessManager: feeAdmin_ZERO_ADDR');
            isFeeAdmin[feeAdmins[i]] = flags[i];
            emit FeeAdminUpdated(feeAdmins[i], flags[i]);
        }
    }

    /// @inheritdoc IWooAccessManager
    function setVaultAdmin(address vaultAdmin, bool flag) external override onlyOwner whenNotPaused {
        require(vaultAdmin != address(0), 'WooAccessManager: vaultAdmin_ZERO_ADDR');
        isVaultAdmin[vaultAdmin] = flag;
        emit VaultAdminUpdated(vaultAdmin, flag);
    }

    /// @inheritdoc IWooAccessManager
    function batchSetVaultAdmin(address[] calldata vaultAdmins, bool[] calldata flags)
        external
        override
        onlyOwner
        whenNotPaused
    {
        require(vaultAdmins.length == flags.length, 'WooAccessManager: length_INVALID');

        for (uint256 i = 0; i < vaultAdmins.length; i++) {
            require(vaultAdmins[i] != address(0), 'WooAccessManager: vaultAdmin_ZERO_ADDR');
            isVaultAdmin[vaultAdmins[i]] = flags[i];
            emit VaultAdminUpdated(vaultAdmins[i], flags[i]);
        }
    }

    /// @inheritdoc IWooAccessManager
    function setRebateAdmin(address rebateAdmin, bool flag) external override onlyOwner whenNotPaused {
        require(rebateAdmin != address(0), 'WooAccessManager: rebateAdmin_ZERO_ADDR');
        isRebateAdmin[rebateAdmin] = flag;
        emit RebateAdminUpdated(rebateAdmin, flag);
    }

    /// @inheritdoc IWooAccessManager
    function batchSetRebateAdmin(address[] calldata rebateAdmins, bool[] calldata flags)
        external
        override
        onlyOwner
        whenNotPaused
    {
        require(rebateAdmins.length == flags.length, 'WooAccessManager: length_INVALID');

        for (uint256 i = 0; i < rebateAdmins.length; i++) {
            require(rebateAdmins[i] != address(0), 'WooAccessManager: rebateAdmin_ZERO_ADDR');
            isRebateAdmin[rebateAdmins[i]] = flags[i];
            emit RebateAdminUpdated(rebateAdmins[i], flags[i]);
        }
    }

    /// @inheritdoc IWooAccessManager
    function setZeroFeeVault(address vault, bool flag) external override onlyOwner whenNotPaused {
        require(vault != address(0), 'WooAccessManager: vault_ZERO_ADDR');
        isZeroFeeVault[vault] = flag;
        emit ZeroFeeVaultUpdated(vault, flag);
    }

    /// @inheritdoc IWooAccessManager
    function batchSetZeroFeeVault(address[] calldata vaults, bool[] calldata flags)
        external
        override
        onlyOwner
        whenNotPaused
    {
        require(vaults.length == flags.length, 'WooAccessManager: length_INVALID');

        for (uint256 i = 0; i < vaults.length; i++) {
            require(vaults[i] != address(0), 'WooAccessManager: vault_ZERO_ADDR');
            isZeroFeeVault[vaults[i]] = flags[i];
            emit ZeroFeeVaultUpdated(vaults[i], flags[i]);
        }
    }

    /// @notice Pause the contract.
    function pause() external onlyOwner {
        super._pause();
    }

    /// @notice Restart the contract.
    function unpause() external onlyOwner {
        super._unpause();
    }
}
