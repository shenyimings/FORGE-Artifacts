// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/PancakeSwap/IMasterChef.sol';
import '../../../interfaces/TraderJoe/IUniswapPair.sol';
import '../../../interfaces/TraderJoe/IUniswapRouter.sol';
import '../../../interfaces/IWooAccessManager.sol';
import '../../../interfaces/IStrategy.sol';

import '../BaseStrategy.sol';

contract StrategyTraderJoeDualLP is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- State Variables ----- */

    uint256 public immutable pid;

    address[] public rewardToLP0Route;
    address[] public rewardToLP1Route;
    address[] public secondRewardToLP0Route;
    address[] public secondRewardToLP1Route;

    address public lpToken0;
    address public lpToken1;

    address public constant reward = address(0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd); // JOE
    address public constant secondReward = address(0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5); // QI
    address public constant uniRouter = address(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
    address public constant masterChef = address(0x188bED1968b795d5c9022F6a0bb5931Ac4c18F00);

    constructor(
        address initVault,
        address initAccessManager,
        uint256 initPid,
        address[] memory initRewardToLP0Route,
        address[] memory initRewardToLP1Route,
        address[] memory initSecondRewardToLP0Route,
        address[] memory initSecondRewardToLP1Route
    ) public BaseStrategy(initVault, initAccessManager) {
        pid = initPid;
        rewardToLP0Route = initRewardToLP0Route;
        rewardToLP1Route = initRewardToLP1Route;
        secondRewardToLP0Route = initSecondRewardToLP0Route;
        secondRewardToLP1Route = initSecondRewardToLP1Route;

        if (initRewardToLP0Route.length == 0) {
            lpToken0 = reward;
        } else {
            require(initRewardToLP0Route[0] == reward);
            lpToken0 = initRewardToLP0Route[initRewardToLP0Route.length - 1];
        }
        if (initRewardToLP1Route.length == 0) {
            lpToken1 = reward;
        } else {
            require(initRewardToLP1Route[0] == reward);
            lpToken1 = initRewardToLP1Route[initRewardToLP1Route.length - 1];
        }
        require(initSecondRewardToLP0Route[0] == secondReward);
        require(initSecondRewardToLP1Route[0] == secondReward);

        require(
            IUniswapV2Pair(want).token0() == lpToken0 || IUniswapV2Pair(want).token0() == lpToken1,
            'StrategyLP: LP_token0_INVALID'
        );
        require(
            IUniswapV2Pair(want).token1() == lpToken0 || IUniswapV2Pair(want).token1() == lpToken1,
            'StrategyLP: LP_token1_INVALID'
        );

        (address lpToken, , , ) = IMasterChef(masterChef).poolInfo(initPid);
        require(lpToken == want, 'StrategyLP: wrong_initPid');

        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function withdraw(uint256 amount) external override nonReentrant {
        require(msg.sender == vault, 'StrategyLP: NOT_VAULT');

        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance < amount) {
            IMasterChef(masterChef).withdraw(pid, amount.sub(wantBalance));
            wantBalance = IERC20(want).balanceOf(address(this));
        }

        // just in case the decimal precision for the very left staking amount
        uint256 withdrawAmount = amount < wantBalance ? amount : wantBalance;

        uint256 fee = chargeWithdrawalFee(withdrawAmount);
        if (withdrawAmount > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmount.sub(fee));
        }
    }

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == vault, 'StrategyLP: EOA_OR_VAULT');

        IMasterChef(masterChef).deposit(pid, 0);
        uint256 rewardAmount = IERC20(reward).balanceOf(address(this));
        uint256 secondRewardAmount = IERC20(secondReward).balanceOf(address(this));
        if (rewardAmount > 0 || secondRewardAmount > 0) {
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
            IMasterChef(masterChef).deposit(pid, wantBalance);
        }
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount, ) = IMasterChef(masterChef).userInfo(pid, address(this));
        return amount;
    }

    /* ----- Private Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, masterChef, 0);
        TransferHelper.safeApprove(want, masterChef, uint256(-1));

        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(reward, uniRouter, uint256(-1));

        TransferHelper.safeApprove(secondReward, uniRouter, 0);
        TransferHelper.safeApprove(secondReward, uniRouter, uint256(-1));

        TransferHelper.safeApprove(lpToken0, uniRouter, 0);
        TransferHelper.safeApprove(lpToken0, uniRouter, uint256(-1));

        TransferHelper.safeApprove(lpToken1, uniRouter, 0);
        TransferHelper.safeApprove(lpToken1, uniRouter, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, masterChef, 0);
        TransferHelper.safeApprove(reward, uniRouter, 0);
        TransferHelper.safeApprove(secondReward, uniRouter, 0);
        TransferHelper.safeApprove(lpToken0, uniRouter, 0);
        TransferHelper.safeApprove(lpToken1, uniRouter, 0);
    }

    function _addLiquidity() private {
        uint256 rewardHalf = IERC20(reward).balanceOf(address(this)).div(2);
        uint256 secondRewardHalf = IERC20(secondReward).balanceOf(address(this)).div(2);

        if (lpToken0 != reward) {
            IUniswapRouter(uniRouter).swapExactTokensForTokens(rewardHalf, 0, rewardToLP0Route, address(this), now);
        }

        if (lpToken1 != reward) {
            IUniswapRouter(uniRouter).swapExactTokensForTokens(rewardHalf, 0, rewardToLP1Route, address(this), now);
        }

        if (lpToken0 != secondReward) {
            IUniswapRouter(uniRouter).swapExactTokensForTokens(
                secondRewardHalf,
                0,
                secondRewardToLP0Route,
                address(this),
                now
            );
        }

        if (lpToken1 != secondReward) {
            IUniswapRouter(uniRouter).swapExactTokensForTokens(
                secondRewardHalf,
                0,
                secondRewardToLP1Route,
                address(this),
                now
            );
        }

        uint256 lp0Balance = IERC20(lpToken0).balanceOf(address(this));
        uint256 lp1Balance = IERC20(lpToken1).balanceOf(address(this));
        IUniswapRouter(uniRouter).addLiquidity(lpToken0, lpToken1, lp0Balance, lp1Balance, 0, 0, address(this), now);
    }

    function retireStrat() external override {
        require(msg.sender == vault, '!vault');
        IMasterChef(masterChef).emergencyWithdraw(pid);
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }

    function emergencyExit() external override onlyAdmin {
        IMasterChef(masterChef).emergencyWithdraw(pid);
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            TransferHelper.safeTransfer(want, vault, wantBalance);
        }
    }
}
