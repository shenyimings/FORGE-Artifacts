// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/Alpaca/IAlpacaVault.sol';
import '../../../interfaces/Alpaca/IFairLaunch.sol';
import '../../../interfaces/PancakeSwap/IPancakeRouter.sol';
import '../../../interfaces/IWooAccessManager.sol';
import '../../../interfaces/IStrategy.sol';
import '../../../interfaces/IWETH.sol';
import '../BaseStrategy.sol';

contract StrategyAlpaca is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- State Variables ----- */

    address public alpacaVault;
    address public fairLaunch;
    uint256 public immutable pid;

    address[] public rewardToWantRoute;

    /* ----- Constant Variables ----- */

    address public constant wrappedEther = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public constant reward = address(0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F);
    address public constant uniRouter = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    constructor(
        address initVault,
        address initAccessManager,
        address initAlpacaVault,
        address initFairLaunch,
        uint256 initPid,
        address[] memory initRewardToWantRoute
    ) public BaseStrategy(initVault, initAccessManager) {
        (address stakeToken, , , , ) = IFairLaunch(initFairLaunch).poolInfo(initPid);
        require(stakeToken == initAlpacaVault, 'StrategyAlpaca: wrong_initPid');
        alpacaVault = initAlpacaVault;
        fairLaunch = initFairLaunch;
        pid = initPid;
        rewardToWantRoute = initRewardToWantRoute;

        _giveAllowances();
    }

    /* ----- Public Functions ----- */

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == address(vault), 'StrategyAlpaca: EOA_or_vault');

        (uint256 amount, , , ) = IFairLaunch(fairLaunch).userInfo(pid, address(this));
        if (amount > 0) {
            IFairLaunch(fairLaunch).harvest(pid);
        }

        uint256 rewardBalance = IERC20(reward).balanceOf(address(this));
        if (rewardBalance > 0) {
            uint256 wantBalBefore = IERC20(want).balanceOf(address(this));
            IPancakeRouter(uniRouter).swapExactTokensForTokens(
                rewardBalance,
                0,
                rewardToWantRoute,
                address(this),
                now.add(600)
            );
            uint256 wantBalAfter = IERC20(want).balanceOf(address(this));
            uint256 perfAmount = wantBalAfter.sub(wantBalBefore);
            chargePerformanceFee(perfAmount);
        }

        deposit();
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBalance = IERC20(want).balanceOf(address(this));

        if (wantBalance > 0) {
            if (want == wrappedEther) {
                IWETH(wrappedEther).withdraw(wantBalance);
                IAlpacaVault(alpacaVault).deposit{value: wantBalance}(wantBalance);
            } else {
                IAlpacaVault(alpacaVault).deposit(wantBalance);
            }
            IFairLaunch(fairLaunch).deposit(address(this), pid, IAlpacaVault(alpacaVault).balanceOf(address(this)));
        }
    }

    function withdraw(uint256 amount) public override nonReentrant {
        require(msg.sender == address(vault), 'StrategyAlpaca: not_vault');
        require(amount > 0, 'StrategyAlpaca: amount_ZERO');

        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance < amount) {
            uint256 ibAmount = amount.mul(IAlpacaVault(alpacaVault).totalSupply()).div(
                IAlpacaVault(alpacaVault).totalToken()
            );
            IFairLaunch(fairLaunch).withdraw(address(this), pid, ibAmount);
            IAlpacaVault(alpacaVault).withdraw(IERC20(alpacaVault).balanceOf(address(this)));
            if (want == wrappedEther) {
                _wrapEther();
            }
            wantBalance = IERC20(want).balanceOf(address(this));
        }

        // just in case the decimal precision for the very left staking amount
        uint256 withdrawAmount = amount < wantBalance ? amount : wantBalance;

        uint256 fee = chargeWithdrawalFee(withdrawAmount);
        if (withdrawAmount > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmount.sub(fee));
        }
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount, , , ) = IFairLaunch(fairLaunch).userInfo(pid, address(this));

        return amount.mul(IAlpacaVault(alpacaVault).totalToken()).div(IAlpacaVault(alpacaVault).totalSupply());
    }

    /* ----- Private Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(reward, uniRouter, uint256(-1));
        TransferHelper.safeApprove(want, alpacaVault, 0);
        TransferHelper.safeApprove(want, alpacaVault, uint256(-1));
        TransferHelper.safeApprove(alpacaVault, fairLaunch, 0);
        TransferHelper.safeApprove(alpacaVault, fairLaunch, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(want, alpacaVault, 0);
        TransferHelper.safeApprove(alpacaVault, fairLaunch, 0);
    }

    function _withdrawAll() private {
        uint256 amount = balanceOfPool();
        uint256 ibAmount = amount.mul(IAlpacaVault(alpacaVault).totalSupply()).div(
            IAlpacaVault(alpacaVault).totalToken()
        );
        IFairLaunch(fairLaunch).withdraw(address(this), pid, ibAmount);
        IAlpacaVault(alpacaVault).withdraw(IERC20(alpacaVault).balanceOf(address(this)));
        if (want == wrappedEther) {
            _wrapEther();
        }
    }

    function _wrapEther() private {
        // NOTE: alpaca vault withdrawal returns the native BNB token; so wrapEther is required.
        uint256 etherBalance = address(this).balance;
        if (etherBalance > 0) {
            IWETH(wrappedEther).deposit{value: etherBalance}();
        }
    }

    /* ----- Admin Functions ----- */

    function retireStrat() external override {
        require(msg.sender == vault, '!vault');
        _withdrawAll();
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }

    function emergencyExit() external override onlyAdmin {
        _withdrawAll();
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }

    receive() external payable {}
}
