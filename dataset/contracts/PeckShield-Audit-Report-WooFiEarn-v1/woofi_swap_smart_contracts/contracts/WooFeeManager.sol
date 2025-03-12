// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

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

import './libraries/InitializableOwnable.sol';
import './libraries/DecimalMath.sol';
import './interfaces/IWooPP.sol';
import './interfaces/IWooRebateManager.sol';
import './interfaces/IWooFeeManager.sol';
import './interfaces/IWooVaultManager.sol';
import './interfaces/IWooAccessManager.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

/// @title Contract to collect transaction fee of Woo private pool.
contract WooFeeManager is InitializableOwnable, ReentrancyGuard, IWooFeeManager {
    /* ----- Type declarations ----- */

    using SafeMath for uint256;
    using DecimalMath for uint256;
    using SafeERC20 for IERC20;

    /* ----- State variables ----- */

    mapping(address => uint256) public override feeRate; // decimal: 18; 1e16 = 1%, 1e15 = 0.1%, 1e14 = 0.01%
    uint256 public vaultRewardRate; // decimal: 18; 1e16 = 1%, 1e15 = 0.1%, 1e14 = 0.01%

    uint256 public rebateAmount;

    address public immutable override quoteToken;
    IWooRebateManager public rebateManager;
    IWooVaultManager public vaultManager;
    IWooAccessManager public accessManager;

    address public treasury;

    /* ----- Modifiers ----- */

    modifier onlyAdmin() {
        require(msg.sender == _OWNER_ || accessManager.isFeeAdmin(msg.sender), 'WooFeeManager: NOT_ADMIN');
        _;
    }

    constructor(
        address newQuoteToken,
        address newRebateManager,
        address newVaultManager,
        address newAccessManager,
        address newTreasury
    ) public {
        require(newQuoteToken != address(0), 'WooFeeManager: quoteToken_ZERO_ADDR');
        initOwner(msg.sender);
        quoteToken = newQuoteToken;
        rebateManager = IWooRebateManager(newRebateManager);
        vaultManager = IWooVaultManager(newVaultManager);
        vaultRewardRate = 1e18;
        accessManager = IWooAccessManager(newAccessManager);
        treasury = newTreasury;
    }

    /* ----- Public Functions ----- */

    function collectFee(uint256 amount, address brokerAddr) external override nonReentrant {
        TransferHelper.safeTransferFrom(quoteToken, msg.sender, address(this), amount);
        uint256 rebateRate = rebateManager.rebateRate(brokerAddr);
        if (rebateRate > 0) {
            uint256 curRebateAmount = amount.mulFloor(rebateRate);
            rebateManager.addRebate(brokerAddr, curRebateAmount);
            rebateAmount = rebateAmount.add(curRebateAmount);
        }
    }

    /* ----- Admin Functions ----- */

    function distributeFees() external override nonReentrant onlyAdmin {
        uint256 balance = IERC20(quoteToken).balanceOf(address(this));
        require(balance > 0, 'WooFeeManager: balance_ZERO');

        // Step 1: distribute the vault balance. Currently, 80% of fee (2 bps) goes to vault manager.
        uint256 vaultAmount = balance.mulFloor(vaultRewardRate);
        if (vaultAmount > 0) {
            TransferHelper.safeApprove(quoteToken, address(vaultManager), vaultAmount);
            TransferHelper.safeTransfer(quoteToken, address(vaultManager), vaultAmount);
            balance = balance.sub(vaultAmount);
        }

        // Step 2: distribute the rebate balance.
        if (rebateAmount > 0) {
            TransferHelper.safeApprove(quoteToken, address(rebateManager), rebateAmount);
            TransferHelper.safeTransfer(quoteToken, address(rebateManager), rebateAmount);

            // NOTE: if balance not enought: certain rebate rates are set incorrectly.
            balance = balance.sub(rebateAmount);
            rebateAmount = 0;
        }

        // Step 3: balance left for treasury
        TransferHelper.safeApprove(quoteToken, treasury, balance);
        TransferHelper.safeTransfer(quoteToken, treasury, balance);
    }

    function setFeeRate(address token, uint256 newFeeRate) external override onlyAdmin {
        require(newFeeRate <= 1e16, 'WooFeeManager: FEE_RATE>1%');
        feeRate[token] = newFeeRate;
        emit FeeRateUpdated(token, newFeeRate);
    }

    function setRebateManager(address newRebateManager) external onlyAdmin {
        require(newRebateManager != address(0), 'WooFeeManager: rebateManager_ZERO_ADDR');
        rebateManager = IWooRebateManager(newRebateManager);
    }

    function setVaultManager(address newVaultManager) external onlyAdmin {
        require(newVaultManager != address(0), 'WooFeeManager: newVaultManager_ZERO_ADDR');
        vaultManager = IWooVaultManager(newVaultManager);
    }

    function setVaultRewardRate(uint256 newVaultRewardRate) external onlyAdmin {
        require(newVaultRewardRate <= 1e18, 'WooFeeManager: vaultRewardRate_INVALID');
        vaultRewardRate = newVaultRewardRate;
    }

    function setAccessManager(address newAccessManager) external onlyOwner {
        require(newAccessManager != address(0), 'WooFeeManager: newAccessManager_ZERO_ADDR');
        accessManager = IWooAccessManager(newAccessManager);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), 'WooFeeManager: newTreasury_ZERO_ADDR');
        treasury = newTreasury;
    }

    function emergencyWithdraw(address token, address to) external onlyOwner {
        require(token != address(0), 'WooFeeManager: token_ZERO_ADDR');
        require(to != address(0), 'WooFeeManager: to_ZERO_ADDR');
        uint256 amount = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransfer(token, to, amount);
        emit Withdraw(token, to, amount);
    }
}
