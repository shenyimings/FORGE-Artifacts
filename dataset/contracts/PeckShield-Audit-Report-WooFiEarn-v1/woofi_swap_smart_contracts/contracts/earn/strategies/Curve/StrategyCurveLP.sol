// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/TraderJoe/IUniswapRouter.sol';
import '../../../interfaces/Curve/ICurveSwap.sol';
import '../../../interfaces/Curve/IRewardsGauge.sol';
import '../BaseStrategy.sol';

contract StrategyCurveLP is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- State Variables ----- */

    // Tokens used
    address public crv;
    address public coReward; // cooperation reward
    address public wNative; // wrapped native
    address public depositToken;

    // Third party contracts
    address public rewardsGauge;
    address public pool;
    uint256 public immutable poolSize;
    uint256 public depositIndex;
    bool public useUnderlying;

    // Routes
    address[] public crvToWNativeRoute;
    address[] public coRewardToWNativeRoute;
    address[] public wNativeToDepositRoute;

    address public crvRouter;
    address public uniRouter;

    uint256 public lastHarvest;

    /* ----- Events ----- */

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address initVault,
        address initAccessManager,
        address initRewardsGauge,
        address initPool,
        uint256 initPoolSize,
        uint256 initDepositIndex,
        bool initUseUnderLying,
        address[] memory initCrvToWNativeRoute,
        address[] memory initCoRewardToWNativeRoute,
        address[] memory initWNativeToDepositRoute,
        address initUniRouter
    ) public BaseStrategy(initVault, initAccessManager) {
        rewardsGauge = initRewardsGauge;
        pool = initPool;
        poolSize = initPoolSize;
        depositIndex = initDepositIndex;
        useUnderlying = initUseUnderLying;

        crv = initCrvToWNativeRoute[0];
        coReward = initCoRewardToWNativeRoute[0];
        wNative = initCrvToWNativeRoute[initCrvToWNativeRoute.length - 1];
        crvToWNativeRoute = initCrvToWNativeRoute;
        coRewardToWNativeRoute = initCoRewardToWNativeRoute;
        crvRouter = initUniRouter;

        require(initWNativeToDepositRoute[0] == wNative, 'StrategyCurveLP: initWNativeToDepositRoute[0] != wNative');
        depositToken = initWNativeToDepositRoute[initWNativeToDepositRoute.length - 1];
        wNativeToDepositRoute = initWNativeToDepositRoute;
        uniRouter = initUniRouter;

        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function crvToWNative() external view returns (address[] memory) {
        return crvToWNativeRoute;
    }

    function coRewardToWNative() external view returns (address[] memory) {
        return coRewardToWNativeRoute;
    }

    function wNativeToDeposit() external view returns (address[] memory) {
        return wNativeToDepositRoute;
    }

    /* ----- Public Functions ----- */

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == vault, 'StrategyCurveLP: !EOA or !Vault');

        IRewardsGauge(rewardsGauge).claim_rewards(address(this));
        uint256 crvBal = IERC20(crv).balanceOf(address(this));
        uint256 coRewardBal = 0;
        if (coReward != address(0)) {
            coRewardBal = IERC20(coReward).balanceOf(address(this));
        }
        uint256 wNativeBal = IERC20(wNative).balanceOf(address(this));
        if (wNativeBal > 0 || crvBal > 0 || coRewardBal > 0) {
            uint256 beforeBal = balanceOfWant();
            _addLiquidity();
            uint256 wantHarvested = balanceOfWant().sub(beforeBal);
            uint256 fee = chargePerformanceFee(wantHarvested);
            deposit();
            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender, wantHarvested.sub(fee), balanceOf());
        }
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBal = balanceOfWant();

        if (wantBal > 0) {
            IRewardsGauge(rewardsGauge).deposit(wantBal);
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 amount) public override nonReentrant {
        require(msg.sender == vault, 'StrategyCurveLP: !Vault');
        require(amount > 0, 'StrategyCurveLP: !amount');

        uint256 wantBal = balanceOfWant();

        if (wantBal < amount) {
            IRewardsGauge(rewardsGauge).withdraw(amount.sub(wantBal));
            wantBal = IERC20(want).balanceOf(address(this));
        }

        uint256 withdrawAmt = amount < wantBal ? amount : wantBal;

        uint256 fee = chargeWithdrawalFee(withdrawAmt);
        if (withdrawAmt > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmt.sub(fee));
        }
        emit Withdraw(balanceOf());
    }

    function balanceOfPool() public view override returns (uint256) {
        return IRewardsGauge(rewardsGauge).balanceOf(address(this));
    }

    /* ----- Internal Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, rewardsGauge, 0);
        TransferHelper.safeApprove(want, rewardsGauge, uint256(-1));
        TransferHelper.safeApprove(crv, crvRouter, 0);
        TransferHelper.safeApprove(crv, crvRouter, uint256(-1));
        if (coReward != address(0)) {
            TransferHelper.safeApprove(coReward, uniRouter, 0);
            TransferHelper.safeApprove(coReward, uniRouter, uint256(-1));
        }
        TransferHelper.safeApprove(wNative, uniRouter, 0);
        TransferHelper.safeApprove(wNative, uniRouter, uint256(-1));
        TransferHelper.safeApprove(depositToken, pool, 0);
        TransferHelper.safeApprove(depositToken, pool, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, rewardsGauge, 0);
        if (coReward != address(0)) {
            TransferHelper.safeApprove(coReward, uniRouter, 0);
        }
        TransferHelper.safeApprove(wNative, uniRouter, 0);
        TransferHelper.safeApprove(crv, crvRouter, 0);
        TransferHelper.safeApprove(depositToken, pool, 0);
    }

    function _addLiquidity() internal {
        uint256 crvBal = IERC20(crv).balanceOf(address(this));
        if (crvBal > 0) {
            IUniswapRouter(crvRouter).swapExactTokensForTokens(
                crvBal,
                0,
                crvToWNativeRoute,
                address(this),
                block.timestamp
            );
        }

        if (coReward != address(0)) {
            uint256 coRewardBal = IERC20(coReward).balanceOf(address(this));
            if (coRewardBal > 0) {
                IUniswapRouter(uniRouter).swapExactTokensForTokens(
                    coRewardBal,
                    0,
                    coRewardToWNativeRoute,
                    address(this),
                    block.timestamp
                );
            }
        }

        uint256 wNativeBal = IERC20(wNative).balanceOf(address(this));
        if (depositToken != wNative) {
            IUniswapRouter(uniRouter).swapExactTokensForTokens(
                wNativeBal,
                0,
                wNativeToDepositRoute,
                address(this),
                block.timestamp
            );
        }

        uint256 depositBal = IERC20(depositToken).balanceOf(address(this));

        if (poolSize == 2) {
            uint256[2] memory amounts;
            amounts[depositIndex] = depositBal;
            if (useUnderlying) ICurveSwap2(pool).add_liquidity(amounts, 0, true);
            else ICurveSwap2(pool).add_liquidity(amounts, 0);
        } else if (poolSize == 3) {
            uint256[3] memory amounts;
            amounts[depositIndex] = depositBal;
            if (useUnderlying) ICurveSwap3(pool).add_liquidity(amounts, 0, true);
            else ICurveSwap3(pool).add_liquidity(amounts, 0);
        } else if (poolSize == 4) {
            uint256[4] memory amounts;
            amounts[depositIndex] = depositBal;
            ICurveSwap4(pool).add_liquidity(amounts, 0);
        } else if (poolSize == 5) {
            uint256[5] memory amounts;
            amounts[depositIndex] = depositBal;
            ICurveSwap5(pool).add_liquidity(amounts, 0);
        }
    }

    /* ----- Admin Functions ----- */

    function setCrvRoute(address newCrvRouter, address[] memory newCrvToWNativeRoute) external onlyAdmin {
        require(newCrvToWNativeRoute[0] == crv, 'StrategyCurveLP: !crv');
        require(newCrvToWNativeRoute[newCrvToWNativeRoute.length - 1] == wNative, 'StrategyCurveLP: !wNative');

        _removeAllowances();
        crvToWNativeRoute = newCrvToWNativeRoute;
        crvRouter = newCrvRouter;
        _giveAllowances();
    }

    function retireStrat() external override {
        require(msg.sender == vault, 'StrategyCurveLP: !Vault');
        IRewardsGauge(rewardsGauge).withdraw(balanceOfPool());
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    function emergencyExit() external override onlyAdmin {
        IRewardsGauge(rewardsGauge).withdraw(balanceOfPool());
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    receive() external payable {}
}
