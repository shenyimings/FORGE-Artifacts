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
import './interfaces/IWooracle.sol';
import './interfaces/IWooVaultManager.sol';
import './interfaces/IWooGuardian.sol';
import './interfaces/AggregatorV3Interface.sol';
import './interfaces/IWooAccessManager.sol';

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

contract WooVaultManager is InitializableOwnable, ReentrancyGuard, IWooVaultManager {
    using SafeMath for uint256;
    using DecimalMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) public override vaultWeight;
    uint256 public totalWeight;

    IWooPP private wooPP;

    address public immutable override quoteToken; // USDT
    address public immutable rewardToken; // WOO

    EnumerableSet.AddressSet private vaultSet;

    IWooAccessManager public accessManager;

    /* ----- Modifiers ----- */

    modifier onlyAdmin() {
        require(msg.sender == _OWNER_ || accessManager.isVaultAdmin(msg.sender), 'WooVaultManager: NOT_ADMIN');
        _;
    }

    constructor(
        address newQuoteToken,
        address newRewardToken,
        address newAccessManager
    ) public {
        require(newQuoteToken != address(0), 'WooVaultManager: INVALID_QUOTE');
        require(newRewardToken != address(0), 'WooVaultManager: INVALID_RAWARD_TOKEN');
        initOwner(msg.sender);
        quoteToken = newQuoteToken;
        rewardToken = newRewardToken;
        accessManager = IWooAccessManager(newAccessManager);
    }

    function allVaults() external view override returns (address[] memory) {
        address[] memory vaults = new address[](vaultSet.length());
        for (uint256 i = 0; i < vaultSet.length(); ++i) {
            vaults[i] = vaultSet.at(i);
        }
        return vaults;
    }

    function addReward(uint256 amount) external override nonReentrant {
        if (amount == 0) {
            return;
        }

        uint256 balanceBefore = IERC20(quoteToken).balanceOf(address(this));
        TransferHelper.safeTransferFrom(quoteToken, msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(quoteToken).balanceOf(address(this));
        require(balanceAfter.sub(balanceBefore) >= amount, 'WooVaultManager: amount INSUFF');
    }

    function pendingReward(address vaultAddr) external view override returns (uint256) {
        require(vaultAddr != address(0), 'WooVaultManager: vaultAddr_ZERO_ADDR');
        uint256 totalReward = IERC20(quoteToken).balanceOf(address(this));
        return totalReward.mul(vaultWeight[vaultAddr]).div(totalWeight);
    }

    function pendingAllReward() external view override returns (uint256) {
        return IERC20(quoteToken).balanceOf(address(this));
    }

    // ----------- Admin Functions ------------- //

    function setVaultWeight(address vaultAddr, uint256 weight) external override onlyAdmin {
        require(vaultAddr != address(0), 'WooVaultManager: vaultAddr_ZERO_ADDR');

        // NOTE: First clear all the pending reward if > 100u to keep the things fair
        if (IERC20(quoteToken).balanceOf(address(this)) >= 1e20) {
            distributeAllReward();
        }

        uint256 prevWeight = vaultWeight[vaultAddr];
        vaultWeight[vaultAddr] = weight;
        totalWeight = totalWeight.add(weight).sub(prevWeight);

        if (weight == 0) {
            vaultSet.remove(vaultAddr);
        } else {
            vaultSet.add(vaultAddr);
        }

        emit VaultWeightUpdated(vaultAddr, weight);
    }

    function distributeAllReward() public override onlyAdmin {
        uint256 totalRewardInQuote = IERC20(quoteToken).balanceOf(address(this));
        if (totalRewardInQuote == 0 || totalWeight == 0) {
            return;
        }

        uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
        TransferHelper.safeApprove(quoteToken, address(wooPP), totalRewardInQuote);
        uint256 wooAmount = IWooPP(wooPP).sellQuote(rewardToken, totalRewardInQuote, 0, address(this), address(0));
        uint256 balanceAfter = IERC20(rewardToken).balanceOf(address(this));
        require(balanceAfter.sub(balanceBefore) >= wooAmount, 'WooVaultManager: woo amount INSUFF');

        for (uint256 i = 0; i < vaultSet.length(); ++i) {
            address vaultAddr = vaultSet.at(i);
            uint256 vaultAmount = wooAmount.mul(vaultWeight[vaultAddr]).div(totalWeight);
            if (vaultAmount > 0) {
                TransferHelper.safeTransfer(rewardToken, vaultAddr, vaultAmount);
            }
            emit RewardDistributed(vaultAddr, vaultAmount);
        }
    }

    function setWooPP(address newWooPP) external onlyAdmin {
        require(newWooPP != address(0), 'WooVaultManager: newWooPP_ZERO_ADDR');
        wooPP = IWooPP(newWooPP);
        require(wooPP.quoteToken() == quoteToken, 'WooVaultManager: wooPP_quote_token_INVALID');
    }

    function setAccessManager(address newAccessManager) external onlyOwner {
        require(newAccessManager != address(0), 'WooVaultManager: newAccessManager_ZERO_ADDR');
        accessManager = IWooAccessManager(newAccessManager);
    }

    function emergencyWithdraw(address token, address to) public onlyOwner {
        require(token != address(0), 'WooVaultManager: token_ZERO_ADDR');
        require(to != address(0), 'WooVaultManager: to_ZERO_ADDR');
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
    }
}
