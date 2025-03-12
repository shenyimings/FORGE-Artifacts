// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Wombex.sol";
import "@overnight-contracts/connectors/contracts/stuff/PancakeV2.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import {IWombatRouter, WombatLibrary} from '@overnight-contracts/connectors/contracts/stuff/Wombat.sol';


contract StrategyWombexUsdt is Strategy {

    // --- structs

    struct StrategyParams {
        address busd;
        address usdt;
        address wom;
        address wmx;
        address lpUsdt;
        address wmxLpUsdt;
        address poolDepositor;
        address pool;
        address pancakeRouter;
        address wombatRouter;
        address oracleBusd;
        address oracleUsdt;
    }

    // --- params

    IERC20 public busd;
    IERC20 public usdt;
    IERC20 public wom;
    IERC20 public wmx;

    IAsset public lpUsdt;
    IBaseRewardPool public wmxLpUsdt;
    IPoolDepositor public poolDepositor;
    IPool public pool;

    IPancakeRouter02 public pancakeRouter;
    IWombatRouter public wombatRouter;

    IPriceFeed public oracleBusd;
    IPriceFeed public oracleUsdt;

    uint256 public busdDm;
    uint256 public usdtDm;
    uint256 public lpUsdtDm;

    // --- events

    event StrategyUpdatedParams();

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        busd = IERC20(params.busd);
        usdt = IERC20(params.usdt);
        wom = IERC20(params.wom);
        wmx = IERC20(params.wmx);

        lpUsdt = IAsset(params.lpUsdt);
        wmxLpUsdt = IBaseRewardPool(params.wmxLpUsdt);
        poolDepositor = IPoolDepositor(params.poolDepositor);
        pool = IPool(lpUsdt.pool());

        pancakeRouter = IPancakeRouter02(params.pancakeRouter);
        wombatRouter = IWombatRouter(params.wombatRouter);

        oracleBusd = IPriceFeed(params.oracleBusd);
        oracleUsdt = IPriceFeed(params.oracleUsdt);

        busdDm = 10 ** IERC20Metadata(params.busd).decimals();
        usdtDm = 10 ** IERC20Metadata(params.usdt).decimals();
        lpUsdtDm = 10 ** IERC20Metadata(params.lpUsdt).decimals();

        usdt.approve(address(poolDepositor), type(uint256).max);
        wmxLpUsdt.approve(address(poolDepositor), type(uint256).max);

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(busd), "Some token not compatible");

        // swap busd to usdt
        uint256 busdBalance = busd.balanceOf(address(this));
        uint256 usdtBalanceOut = WombatLibrary.getAmountOut(
            wombatRouter,
            address(busd),
            address(usdt),
            address(pool),
            busdBalance
        );
        if (usdtBalanceOut > 0) {
            uint256 usdtBalanceOracle = ChainlinkLibrary.convertTokenToToken(
                busdBalance,
                busdDm,
                usdtDm,
                oracleBusd,
                oracleUsdt
            );
            WombatLibrary.swapExactTokensForTokens(
                wombatRouter,
                address(busd),
                address(usdt),
                address(pool),
                busdBalance,
                OvnMath.subBasisPoints(usdtBalanceOracle, swapSlippageBP),
                address(this)
            );
        }

        // get potential deposit amount
        uint256 usdtBalance = usdt.balanceOf(address(this));
        (uint256 lpUsdtAmount,) = poolDepositor.getDepositAmountOut(address(lpUsdt), usdtBalance);
        // deposit
        poolDepositor.deposit(address(lpUsdt), usdtBalance, OvnMath.subBasisPoints(lpUsdtAmount, 1), true);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busd), "Some token not compatible");

        // calculate swap _amount usdt to busd
        uint256 busdAmountForUsdtAmount = WombatLibrary.getAmountOut(
            wombatRouter,
            address(usdt),
            address(busd),
            address(pool),
            _amount
        );
        // get usdtAmount for _amount in busd
        uint256 usdtAmount = _amount * _amount / busdAmountForUsdtAmount;
        // get withdraw amount for 1 LP
        (uint256 usdtAmountOneAsset,) = poolDepositor.getWithdrawAmountOut(address(lpUsdt), lpUsdtDm);
        // add 1bp for smooth withdraw
        uint256 lpUsdtAmount = OvnMath.addBasisPoints(usdtAmount, 1) * lpUsdtDm / usdtAmountOneAsset;

        // withdraw
        poolDepositor.withdraw(address(lpUsdt), lpUsdtAmount, usdtAmount, address(this));

        // swap usdt to busd
        uint256 usdtBalance = usdt.balanceOf(address(this));
        uint256 busdBalanceOut = WombatLibrary.getAmountOut(
            wombatRouter,
            address(usdt),
            address(busd),
            address(pool),
            usdtBalance
        );
        if (busdBalanceOut > 0) {
            uint256 busdBalanceOracle = ChainlinkLibrary.convertTokenToToken(
                usdtBalance,
                usdtDm,
                busdDm,
                oracleUsdt,
                oracleBusd
            );
            WombatLibrary.swapExactTokensForTokens(
                wombatRouter,
                address(usdt),
                address(busd),
                address(pool),
                usdtBalance,
                OvnMath.subBasisPoints(busdBalanceOracle, swapSlippageBP),
                address(this)
            );
        }

        return busd.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busd), "Some token not compatible");

        uint256 lpUsdtBalance = wmxLpUsdt.balanceOf(address(this));
        if (lpUsdtBalance > 0) {
            // get withdraw amount
            (uint256 usdtAmount,) = poolDepositor.getWithdrawAmountOut(address(lpUsdt), lpUsdtBalance);
            // withdraw
            poolDepositor.withdraw(address(lpUsdt), lpUsdtBalance, OvnMath.subBasisPoints(usdtAmount, 1), address(this));
        }

        // swap usdt to busd
        uint256 usdtBalance = usdt.balanceOf(address(this));
        uint256 busdBalanceOut = WombatLibrary.getAmountOut(
            wombatRouter,
            address(usdt),
            address(busd),
            address(pool),
            usdtBalance
        );
        if (busdBalanceOut > 0) {
            uint256 busdBalanceOracle = ChainlinkLibrary.convertTokenToToken(
                usdtBalance,
                usdtDm,
                busdDm,
                oracleUsdt,
                oracleBusd
            );
            WombatLibrary.swapExactTokensForTokens(
                wombatRouter,
                address(usdt),
                address(busd),
                address(pool),
                usdtBalance,
                OvnMath.subBasisPoints(busdBalanceOracle, swapSlippageBP),
                address(this)
            );
        }

        return busd.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 busdBalance = busd.balanceOf(address(this));
        uint256 usdtBalance = usdt.balanceOf(address(this));

        uint256 lpUsdtBalance = wmxLpUsdt.balanceOf(address(this));
        if (lpUsdtBalance > 0) {
            (uint256 usdtAmount,) = poolDepositor.getWithdrawAmountOut(address(lpUsdt), lpUsdtBalance);
            usdtBalance += usdtAmount;
        }

        if (usdtBalance > 0) {
            if (nav) {
                busdBalance += ChainlinkLibrary.convertTokenToToken(
                    usdtBalance,
                    usdtDm,
                    busdDm,
                    oracleUsdt,
                    oracleBusd
                );
            } else {
                busdBalance += WombatLibrary.getAmountOut(
                    wombatRouter,
                    address(usdt),
                    address(busd),
                    address(pool),
                    usdtBalance
                );
            }
        }

        return busdBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        uint256 lpUsdtBalance = wmxLpUsdt.balanceOf(address(this));
        if (lpUsdtBalance > 0) {
            wmxLpUsdt.getReward(address(this), false);
        }

        // sell rewards
        uint256 totalBusd;

        uint256 womBalance = wom.balanceOf(address(this));
        if (womBalance > 0) {
            uint256 amountOut = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(wom),
                address(busd),
                womBalance
            );

            if (amountOut > 0) {
                uint256 womBusd = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(wom),
                    address(busd),
                    womBalance,
                    amountOut * 99 / 100,
                    address(this)
                );

                totalBusd += womBusd;
            }
        }

        uint256 wmxBalance = wmx.balanceOf(address(this));
        if (wmxBalance > 0) {
            uint256 amountOut = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(wmx),
                address(busd),
                wmxBalance
            );

            if (amountOut > 0) {
                uint256 wmxBusd = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(wmx),
                    address(busd),
                    wmxBalance,
                    amountOut * 99 / 100,
                    address(this)
                );

                totalBusd += wmxBusd;
            }
        }

        if (totalBusd > 0) {
            busd.transfer(_to, totalBusd);
        }

        return totalBusd;
    }

}
