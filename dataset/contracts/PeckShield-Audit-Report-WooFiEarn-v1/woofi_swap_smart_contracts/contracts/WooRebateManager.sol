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
import './interfaces/IWooRebateManager.sol';
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

contract WooRebateManager is InitializableOwnable, ReentrancyGuard, IWooRebateManager {
    using SafeMath for uint256;
    using DecimalMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Note: this is the percent rate of the total swap fee (not the swap volume)
    // decimal: 18; 1e16 = 1%, 1e15 = 0.1%, 1e14 = 0.01%
    //
    // e.g. suppose:
    //   rebateRate = 1e17 (10%), so the rebate amount is total_swap_fee * 10%.
    mapping(address => uint256) public override rebateRate;
    EnumerableSet.AddressSet private rebateAddressSet;

    // pending rebate amount in quote token
    mapping(address => uint256) public pendingRebate;

    IWooPP private wooPP;

    address public immutable override quoteToken; // USDT
    address public rewardToken; // Any Token

    IWooAccessManager public accessManager;

    /* ----- Modifiers ----- */

    modifier onlyAdmin() {
        require(msg.sender == _OWNER_ || accessManager.isRebateAdmin(msg.sender), 'WooRebateManager: NOT_ADMIN');
        _;
    }

    constructor(
        address newQuoteToken,
        address newRewardToken,
        address newAccessManager
    ) public {
        require(newQuoteToken != address(0), 'WooRebateManager: INVALID_QUOTE');
        require(newRewardToken != address(0), 'WooRebateManager: INVALID_REWARD_TOKEN');
        initOwner(msg.sender);
        quoteToken = newQuoteToken;
        rewardToken = newRewardToken;
        accessManager = IWooAccessManager(newAccessManager);
    }

    function pendingRebateInUSDT(address brokerAddr) external view override returns (uint256) {
        require(brokerAddr != address(0), 'WooRebateManager: zero_brokerAddr');
        return pendingRebate[brokerAddr];
    }

    function pendingRebateInWOO(address brokerAddr) external view override returns (uint256) {
        require(brokerAddr != address(0), 'WooRebateManager: zero_brokerAddr');
        return wooPP.querySellQuote(rewardToken, pendingRebate[brokerAddr]);
    }

    function claimRebate() external override nonReentrant {
        require(pendingRebate[msg.sender] > 0, 'WooRebateManager: NO_pending_rebate');

        uint256 quoteAmount = pendingRebate[msg.sender];
        // Note: set the pending rebate early to make external interactions safe.
        pendingRebate[msg.sender] = 0;

        uint256 rewardAmount;
        if (rewardToken == quoteToken) {
            rewardAmount = quoteAmount;
        } else {
            uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
            TransferHelper.safeApprove(quoteToken, address(wooPP), quoteAmount);
            rewardAmount = wooPP.sellQuote(rewardToken, quoteAmount, 0, address(this), address(0));
            uint256 balanceAfter = IERC20(rewardToken).balanceOf(address(this));
            require(balanceAfter.sub(balanceBefore) >= rewardAmount, 'WooRebateManager: woo amount INSUFF');
        }

        if (rewardAmount > 0) {
            TransferHelper.safeTransfer(rewardToken, msg.sender, rewardAmount);
        }

        emit ClaimReward(msg.sender, rewardAmount);
    }

    function allRebateAddresses() external view returns (address[] memory) {
        address[] memory rebateAddresses = new address[](rebateAddressSet.length());
        for (uint256 i = 0; i < rebateAddressSet.length(); ++i) {
            rebateAddresses[i] = rebateAddressSet.at(i);
        }
        return rebateAddresses;
    }

    function allRebateAddressesLength() external view returns (uint256) {
        return rebateAddressSet.length();
    }

    /* ----- Admin Functions ----- */

    function addRebate(address brokerAddr, uint256 amountInUSDT) external override nonReentrant onlyAdmin {
        if (brokerAddr == address(0)) {
            return;
        }
        pendingRebate[brokerAddr] = amountInUSDT.add(pendingRebate[brokerAddr]);
    }

    function setRebateRate(address brokerAddr, uint256 rate) external override onlyAdmin {
        require(brokerAddr != address(0), 'WooRebateManager: brokerAddr_ZERO_ADDR');
        require(rate <= 1e18, 'WooRebateManager: INVALID_USER_REWARD_RATE'); // rate <= 100%
        rebateRate[brokerAddr] = rate;
        if (rate == 0) {
            rebateAddressSet.remove(brokerAddr);
        } else {
            rebateAddressSet.add(brokerAddr);
        }
        emit RebateRateUpdated(brokerAddr, rate);
    }

    function setWooPP(address newWooPP) external onlyAdmin {
        require(newWooPP != address(0), 'WooRebateManager: wooPP_ZERO_ADDR');
        wooPP = IWooPP(newWooPP);
        require(wooPP.quoteToken() == quoteToken, 'WooRebateManager: wooPP_quote_token_INVALID');
    }

    function setAccessManager(address newAccessManager) external onlyOwner {
        require(newAccessManager != address(0), 'WooRebateManager: newAccessManager_ZERO_ADDR');
        accessManager = IWooAccessManager(newAccessManager);
    }

    function setRewardToken(address newRewardToken) external onlyAdmin {
        require(newRewardToken != address(0), 'WooRebateManager: rewardToken_ZERO_ADDR');
        rewardToken = newRewardToken;
    }

    function emergencyWithdraw(address token, address to) public onlyOwner {
        require(token != address(0), 'WooRebateManager: token_ZERO_ADDR');
        require(to != address(0), 'WooRebateManager: to_ZERO_ADDR');
        uint256 amount = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransfer(token, to, amount);
        emit Withdraw(token, to, amount);
    }
}
