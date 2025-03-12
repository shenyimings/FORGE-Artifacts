// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/TraderJoe/IStableJoeStaking.sol';
import '../../../interfaces/BankerJoe/IJoeRouter.sol';
import '../BaseStrategy.sol';

contract StrategySJoe is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- Constant Variables ----- */

    address public constant staking = address(0x1a731B2299E22FbAC282E7094EdA41046343Cb51); // Joe staking contract
    address public constant uniRouter = address(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // JoeRouter02
    address public constant reward = address(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E); // USDC

    address[] public rewardToWantRoute; // usdc -> joe

    constructor(address initVault, address initAccessManager) public BaseStrategy(initVault, initAccessManager) {
        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            IStableJoeStaking(staking).deposit(wantBalance);
        }
    }

    function withdraw(uint256 amount) external override nonReentrant {
        require(msg.sender == address(vault), 'StrategySJoe: NOT_VAULT');

        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance < amount) {
            IStableJoeStaking(staking).withdraw(amount.sub(wantBalance));
            wantBalance = IERC20(want).balanceOf(address(this));
        }

        require(wantBalance >= amount.mul(9999).div(10000), 'StrategySJoe: WITHDRAW_INSUFF_AMOUNT');
        uint256 withdrawAmount = amount < wantBalance ? amount : wantBalance;

        uint256 fee = chargeWithdrawalFee(withdrawAmount);
        if (withdrawAmount > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmount.sub(fee));
        }
    }

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == address(vault), 'StrategySJoe: EOA_or_vault');

        uint256 balanceBefore = IERC20(want).balanceOf(address(this));

        IStableJoeStaking(staking).deposit(0); // to harvest the reward

        uint256 rewardBal = IERC20(reward).balanceOf(address(this));
        if (rewardBal > 0 && reward != want) {
            IJoeRouter(uniRouter).swapExactTokensForTokens(rewardBal, 0, rewardToWantRoute, address(this), now);
        }

        uint256 balanceAfter = IERC20(want).balanceOf(address(this));

        uint256 perfAmount = balanceAfter.sub(balanceBefore);
        chargePerformanceFee(perfAmount);
        deposit();
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount, ) = IStableJoeStaking(staking).getUserInfo(address(this), reward);
        return amount;
    }

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, staking, 0);
        TransferHelper.safeApprove(want, staking, uint256(-1));
        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(reward, uniRouter, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, staking, 0);
        TransferHelper.safeApprove(reward, uniRouter, 0);
    }

    /* ----- Admin Functions ----- */

    function setRewardToWantRoute(address[] memory _rewardToWantRoute) external onlyAdmin {
        rewardToWantRoute = _rewardToWantRoute;
    }

    function retireStrat() external override {
        require(msg.sender == vault, '!vault');
        IStableJoeStaking(staking).emergencyWithdraw();
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }

    function emergencyExit() external override onlyAdmin {
        IStableJoeStaking(staking).emergencyWithdraw();
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }
}
