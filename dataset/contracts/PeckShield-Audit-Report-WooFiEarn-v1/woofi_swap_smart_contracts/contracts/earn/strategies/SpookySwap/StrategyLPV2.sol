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

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/SpookySwap/IMasterChefV2.sol';
import '../../../interfaces/SpookySwap/ISpookyPair.sol';
import '../../../interfaces/PancakeSwap/IPancakeRouter.sol';
import '../../../interfaces/IWooAccessManager.sol';
import '../../../interfaces/IStrategy.sol';

import '../BaseStrategy.sol';

contract StrategySpookySwapLPV2 is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- State Variables ----- */

    uint256 public immutable pid;

    address[] public rewardToLP0Route;
    address[] public rewardToLP1Route;

    address public lpToken0;
    address public lpToken1;

    address public constant reward = address(0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE); // BOO
    address public constant uniRouter = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    address public constant masterChefV2 = address(0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD);

    constructor(
        address _vault,
        address _accessManager,
        uint256 _pid,
        address[] memory _rewardToLP0Route,
        address[] memory _rewardToLP1Route
    ) public BaseStrategy(_vault, _accessManager) {
        pid = _pid;
        rewardToLP0Route = _rewardToLP0Route;
        rewardToLP1Route = _rewardToLP1Route;

        if (_rewardToLP0Route.length == 0) {
            lpToken0 = reward;
        } else {
            require(_rewardToLP0Route[0] == reward);
            lpToken0 = _rewardToLP0Route[_rewardToLP0Route.length - 1];
        }
        if (_rewardToLP1Route.length == 0) {
            lpToken1 = reward;
        } else {
            require(_rewardToLP1Route[0] == reward);
            lpToken1 = _rewardToLP1Route[_rewardToLP1Route.length - 1];
        }

        require(
            ISpookyPair(want).token0() == lpToken0 || ISpookyPair(want).token0() == lpToken1,
            'StrategySpookySwapLPV2: token0_INVALID'
        );
        require(
            ISpookyPair(want).token1() == lpToken0 || ISpookyPair(want).token1() == lpToken1,
            'StrategySpookySwapLPV2: token1_INVALID'
        );

        address lpToken = IMasterChefV2(masterChefV2).lpToken(_pid);
        require(lpToken == want, 'StrategySpookySwapLPV2: _pid_INVALID');

        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function withdraw(uint256 amount) external override nonReentrant {
        require(msg.sender == vault, 'StrategySpookySwapLPV2: NOT_VAULT');

        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance < amount) {
            IMasterChefV2(masterChefV2).withdraw(pid, amount.sub(wantBalance));
            wantBalance = IERC20(want).balanceOf(address(this));
        }

        // just in case the decimal precision for the very left staking amount
        require(wantBalance >= amount.mul(999).div(1000), 'StrategySpookySwapLPV2: WITHDRAW_INSUFF_AMOUNT');
        uint256 withdrawAmount = amount < wantBalance ? amount : wantBalance;

        uint256 fee = chargeWithdrawalFee(withdrawAmount);
        if (withdrawAmount > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmount.sub(fee));
        }
    }

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == vault, 'StrategySpookySwapLPV2: EOA_OR_VAULT');

        IMasterChefV2(masterChefV2).withdraw(pid, 0);
        uint256 rewardAmount = IERC20(reward).balanceOf(address(this));
        if (rewardAmount > 0) {
            uint256 wantBefore = IERC20(want).balanceOf(address(this));
            _addLiquidity();
            uint256 wantAfter = IERC20(want).balanceOf(address(this));
            uint256 perfAmount = wantAfter.sub(wantBefore);
            chargePerformanceFee(perfAmount);
        }
        deposit();
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            IMasterChefV2(masterChefV2).deposit(pid, wantBalance);
        }
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount, ) = IMasterChefV2(masterChefV2).userInfo(pid, address(this));
        return amount;
    }

    /* ----- Private Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, masterChefV2, 0);
        TransferHelper.safeApprove(want, masterChefV2, uint256(-1));

        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(reward, uniRouter, uint256(-1));

        TransferHelper.safeApprove(lpToken0, uniRouter, 0);
        TransferHelper.safeApprove(lpToken0, uniRouter, uint256(-1));

        TransferHelper.safeApprove(lpToken1, uniRouter, 0);
        TransferHelper.safeApprove(lpToken1, uniRouter, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, masterChefV2, 0);
        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(lpToken0, uniRouter, 0);
        TransferHelper.safeApprove(lpToken1, uniRouter, 0);
    }

    function _addLiquidity() private {
        uint256 rewardHalf = IERC20(reward).balanceOf(address(this)).div(2);

        if (lpToken0 != reward) {
            IPancakeRouter(uniRouter).swapExactTokensForTokens(rewardHalf, 0, rewardToLP0Route, address(this), now);
        }

        if (lpToken1 != reward) {
            IPancakeRouter(uniRouter).swapExactTokensForTokens(rewardHalf, 0, rewardToLP1Route, address(this), now);
        }

        uint256 lp0Balance = IERC20(lpToken0).balanceOf(address(this));
        uint256 lp1Balance = IERC20(lpToken1).balanceOf(address(this));
        IPancakeRouter(uniRouter).addLiquidity(lpToken0, lpToken1, lp0Balance, lp1Balance, 0, 0, address(this), now);
    }

    function retireStrat() external override {
        require(msg.sender == vault, 'StrategySpookySwapLPV2: NOT_VAULT');
        IMasterChefV2(masterChefV2).emergencyWithdraw(pid, vault);
    }

    function emergencyExit() external override onlyAdmin {
        IMasterChefV2(masterChefV2).emergencyWithdraw(pid, vault);
    }
}
