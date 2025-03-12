// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
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
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';

import '../../interfaces/IWooAccessManager.sol';

import '../../libraries/PausableUpgradeable.sol';

abstract contract BaseMaxiVault is PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;

    /* ----- State Variables ----- */

    address public depositToken;
    address public rewardToken;

    address public wooAccessManager;

    uint256 public performanceFee;
    uint256 public withdrawalFee;
    address public performanceTreasury;
    address public withdrawalTreasury;

    /* ----- Constant Variables ----- */

    uint256 public constant FEE_DENOMINATOR = 10000;

    /* ----- Event ----- */

    event PerformanceFeeUpdated(uint256 fee);
    event WithdrawalFeeUpdated(uint256 fee);

    /* ----- Initializer ----- */

    function __BaseMaxiVault_init(address _wooAccessManager) internal initializer {
        require(_wooAccessManager != address(0), 'BaseMaxiVault: _wooAccessManager_ZERO_ADDRESS');

        __PausableUpgradeable_init();
        __ReentrancyGuard_init();

        wooAccessManager = _wooAccessManager;

        performanceFee = 300; // 1 in 10000th -> 100: 1%, 300: 3%
        withdrawalFee = 0; // 1 in 10000th -> 1: 0.01%, 10: 0.1%
        performanceTreasury = 0x4094D7A17a387795838c7aba4687387B0d32BCf3;
        withdrawalTreasury = 0x4094D7A17a387795838c7aba4687387B0d32BCf3;
    }

    /* ----- Modifier ----- */

    modifier onlyAdmin() {
        require(
            owner() == msg.sender || IWooAccessManager(wooAccessManager).isVaultAdmin(msg.sender),
            'WOOFiMaximizerVault: NOT_ADMIN'
        );
        _;
    }

    /* ----- Internal Functions ----- */

    function _chargePerformanceFee(address _token, uint256 _amount) internal returns (uint256) {
        uint256 fee = _amount.mul(performanceFee).div(FEE_DENOMINATOR);
        if (fee > 0) TransferHelper.safeTransfer(_token, performanceTreasury, fee);
        return fee;
    }

    function _chargeWithdrawalFee(address _token, uint256 _amount) internal returns (uint256) {
        uint256 fee = _amount.mul(performanceFee).div(FEE_DENOMINATOR);
        if (fee > 0) TransferHelper.safeTransfer(_token, withdrawalTreasury, fee);
        return fee;
    }

    /* ----- Abstract Method ----- */

    function emergencyExit() external virtual;

    function depositAll() external virtual;

    function withdrawAll() external virtual;

    function deposit(uint256 _amount) public virtual;

    function withdraw(uint256 _amount) public virtual;

    function harvest() public virtual;

    function depositToPool() public virtual; // admin function

    function withdrawFromPool() public virtual; // admin function

    function _giveAllowances() internal virtual;

    function _removeAllowances() internal virtual;

    /* ----- Admin Functions ----- */

    function setPerformanceFee(uint256 _fee) external onlyAdmin {
        require(_fee <= FEE_DENOMINATOR, 'BaseMaxiVault: _fee_EXCEEDS_FEE_DENOMINATOR');
        performanceFee = _fee;
        emit PerformanceFeeUpdated(_fee);
    }

    function setWithdrawalFee(uint256 _fee) external onlyAdmin {
        require(_fee <= 500, 'BaseMaxiVault: fee_EXCEEDS_5%'); // less than 5%
        withdrawalFee = _fee;
        emit WithdrawalFeeUpdated(_fee);
    }

    function setPerformanceTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), 'BaseMaxiVault: _treasury_ZERO_ADDRESS');
        performanceTreasury = _treasury;
    }

    function setWithdrawalTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), 'BaseMaxiVault: _treasury_ZERO_ADDRESS');
        withdrawalTreasury = _treasury;
    }

    function setWooAccessManager(address _wooAccessManager) external onlyAdmin {
        require(_wooAccessManager != address(0), 'BaseMaxiVault: _wooAccessManager_ZERO_ADDRESS');
        wooAccessManager = _wooAccessManager;
    }

    function pause() external onlyAdmin {
        setPaused(true);
        _removeAllowances();
    }

    function unpause() external onlyAdmin {
        setPaused(false);
        _giveAllowances();
        depositToPool();
    }

    function inCaseTokensGetStuck(address _stuckToken) external onlyAdmin {
        require(_stuckToken != address(0), 'BaseMaxiVault: _stuckToken_ZERO_ADDRESS');
        require(_stuckToken != depositToken, 'BaseMaxiVault: _stuckToken_MUST_NOT_depositToken');
        require(_stuckToken != rewardToken, 'BaseMaxiVault: _stuckToken_MUST_NOT_rewardToken');

        uint256 bal = IERC20(_stuckToken).balanceOf(address(this));
        if (bal > 0) TransferHelper.safeTransfer(_stuckToken, msg.sender, bal);
    }

    function inCaseNativeTokensGetStuck() external onlyAdmin {
        // NOTE: vault never needs native tokens to do the yield farming;
        // This native token balance indicates a user's incorrect transfer.
        if (address(this).balance > 0) TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }
}
