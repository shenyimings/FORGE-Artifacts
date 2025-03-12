// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/VectorFinance/IPoolHelper.sol';
import '../../../interfaces/VectorFinance/IMainStaking.sol';
import '../../../interfaces/BankerJoe/IJoeRouter.sol';
import '../BaseStrategy.sol';

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
contract StrategyPlatypusVector is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- State Variables ----- */

    // DepositPool list:
    // usdc.e pool helper: 0x257D69AA678e0A8DA6DFDA6A16CdF2052A460b45
    IPoolHelper public poolHelper;
    address public mainStaking = address(0x8B3d9F0017FA369cD8C164D0Cc078bf4cA588aE5);

    address[] public reward1ToWantRoute;
    address[] public reward2ToWantRoute;
    uint256 public lastHarvest;
    uint256 public slippage = 10; // 100 = 1%; 10 = 0.1%; 1 = 0.01%; default: 0.1%

    /* ----- Constant Variables ----- */

    address public constant wrappedEther = address(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7); // WAVAX
    address public constant reward1 = address(0xe6E7e03b60c0F8DaAE5Db98B03831610A60FfE1B); // VTX
    address public constant reward2 = address(0x22d4002028f537599bE9f666d1c4Fa138522f9c8); // PTP
    address public constant uniRouter = address(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // JoeRouter02

    /* ----- Events ----- */

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address _vault,
        address _accessManager,
        address _poolHelper,
        address[] memory _reward1ToWantRoute,
        address[] memory _reward2ToWantRoute
    ) public BaseStrategy(_vault, _accessManager) {
        poolHelper = IPoolHelper(_poolHelper);
        reward1ToWantRoute = _reward1ToWantRoute;
        reward2ToWantRoute = _reward2ToWantRoute;

        require(IVault(_vault).want() == poolHelper.depositToken(), 'StrategyPlatypusVector: !poolHelper');
        require(
            reward1ToWantRoute.length > 0 && reward1ToWantRoute[reward1ToWantRoute.length - 1] == want,
            'StrategyPlatypusVector: !route'
        );
        require(
            reward2ToWantRoute.length > 0 && reward2ToWantRoute[reward2ToWantRoute.length - 1] == want,
            'StrategyPlatypusVector: !route'
        );

        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function reward1ToWant() external view returns (address[] memory) {
        return reward1ToWantRoute;
    }

    function reward2ToWant() external view returns (address[] memory) {
        return reward2ToWantRoute;
    }

    /* ----- Public Functions ----- */

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == address(vault), 'StrategyPlatypusVector: EOA_or_vault');

        // NOTE: in case of upgrading, withdraw all the funds and pause the strategy.
        if (IMainStaking(mainStaking).nextImplementation() != address(0)) {
            _withdrawAll();
            pause();
            return;
        }

        uint256 beforeBal = balanceOfWant();

        poolHelper.getReward(); // Harvest VTX and PTP rewards

        _swapRewardToWant(reward1, reward1ToWantRoute);
        _swapRewardToWant(reward2, reward2ToWantRoute);

        uint256 wantHarvested = balanceOfWant().sub(beforeBal);
        uint256 fee = chargePerformanceFee(wantHarvested);
        deposit();

        lastHarvest = block.timestamp;
        emit StratHarvest(msg.sender, wantHarvested.sub(fee), balanceOf());
    }

    function _swapRewardToWant(address reward, address[] memory route) private {
        uint256 rewardBal = IERC20(reward).balanceOf(address(this));

        // rewardBal == 0: means the current token reward ended
        // reward == want: no need to swap
        if (rewardBal > 0 && reward != want) {
            require(route.length > 0, 'StrategyPlatypusVector: SWAP_ROUTE_INVALID');
            IJoeRouter(uniRouter).swapExactTokensForTokens(rewardBal, 0, route, address(this), now);
        }
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBal = balanceOfWant();
        if (wantBal > 0) {
            poolHelper.deposit(wantBal);
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 amount) public override nonReentrant {
        require(msg.sender == vault, 'StrategyPlatypusVector: !vault');
        require(amount > 0, 'StrategyPlatypusVector: !amount');

        uint256 wantBal = balanceOfWant();

        if (wantBal < amount) {
            uint256 amountToWithdraw = amount.sub(wantBal);
            // minAmount with slippage
            uint256 minAmount = amountToWithdraw.mul(uint256(10000).sub(slippage)).div(10000);
            poolHelper.withdraw(amountToWithdraw, minAmount);
            uint256 newWantBal = IERC20(want).balanceOf(address(this));
            require(newWantBal > wantBal, 'StrategyPlatypusVector: !newWantBal');
            wantBal = newWantBal;
        }

        uint256 withdrawAmt = amount < wantBal ? amount : wantBal;
        uint256 fee = chargeWithdrawalFee(withdrawAmt);
        if (withdrawAmt > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmt.sub(fee));
        }

        emit Withdraw(balanceOf());
    }

    function balanceOfPool() public view override returns (uint256) {
        return poolHelper.depositTokenBalance();
    }

    /* ----- Internal Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, mainStaking, 0);
        TransferHelper.safeApprove(want, mainStaking, uint256(-1));
        TransferHelper.safeApprove(reward1, uniRouter, 0);
        TransferHelper.safeApprove(reward1, uniRouter, uint256(-1));
        TransferHelper.safeApprove(reward2, uniRouter, 0);
        TransferHelper.safeApprove(reward2, uniRouter, uint256(-1));
        TransferHelper.safeApprove(wrappedEther, uniRouter, 0);
        TransferHelper.safeApprove(wrappedEther, uniRouter, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, mainStaking, 0);
        TransferHelper.safeApprove(reward1, uniRouter, 0);
        TransferHelper.safeApprove(reward2, uniRouter, 0);
        TransferHelper.safeApprove(wrappedEther, uniRouter, 0);
    }

    function _withdrawAll() internal {
        uint256 stakingBal = balanceOfPool();
        if (stakingBal > 0) {
            // minAmount with slippage
            uint256 minAmount = stakingBal.mul(uint256(10000).sub(slippage)).div(10000);
            poolHelper.withdraw(stakingBal, minAmount);
        }
    }

    /* ----- Admin Functions ----- */

    function setPoolHelper(address newPoolHelper) external onlyAdmin {
        require(newPoolHelper != address(0), 'StrategyPlatypusVector: !newPoolHelper');
        poolHelper = IPoolHelper(newPoolHelper);
    }

    function setSlippage(uint256 newSlippage) external onlyAdmin {
        slippage = newSlippage;
    }

    function retireStrat() external override {
        require(msg.sender == vault, 'StrategyPlatypusVector: !vault');
        // call harvest explicitly if needed
        _withdrawAll();
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    function emergencyExit() external override onlyAdmin {
        _withdrawAll();
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    receive() external payable {}
}
