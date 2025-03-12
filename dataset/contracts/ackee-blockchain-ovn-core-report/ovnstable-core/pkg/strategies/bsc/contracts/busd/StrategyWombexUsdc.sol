// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Wombex.sol";
import "@overnight-contracts/connectors/contracts/stuff/PancakeV2.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import {IWombatRouter, WombatLibrary} from '@overnight-contracts/connectors/contracts/stuff/Wombat.sol';


contract StrategyWombexUsdc is Strategy {

    // --- structs

    struct StrategyParams {
        address busd;
        address usdc;
        address wom;
        address wmx;
        address lpUsdc;
        address wmxLpUsdc;
        address poolDepositor;
        address pool;
        address pancakeRouter;
        address wombatRouter;
        address oracleBusd;
        address oracleUsdc;
    }

    // --- params

    IERC20 public busd;
    IERC20 public usdc;
    IERC20 public wom;
    IERC20 public wmx;

    IAsset public lpUsdc;
    IBaseRewardPool public wmxLpUsdc;
    IPoolDepositor public poolDepositor;
    IPool public pool;

    IPancakeRouter02 public pancakeRouter;
    IWombatRouter public wombatRouter;

    IPriceFeed public oracleBusd;
    IPriceFeed public oracleUsdc;

    uint256 public busdDm;
    uint256 public usdcDm;
    uint256 public lpUsdcDm;

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
        usdc = IERC20(params.usdc);
        wom = IERC20(params.wom);
        wmx = IERC20(params.wmx);

        lpUsdc = IAsset(params.lpUsdc);
        wmxLpUsdc = IBaseRewardPool(params.wmxLpUsdc);
        poolDepositor = IPoolDepositor(params.poolDepositor);
        pool = IPool(lpUsdc.pool());

        pancakeRouter = IPancakeRouter02(params.pancakeRouter);
        wombatRouter = IWombatRouter(params.wombatRouter);

        oracleBusd = IPriceFeed(params.oracleBusd);
        oracleUsdc = IPriceFeed(params.oracleUsdc);

        busdDm = 10 ** IERC20Metadata(params.busd).decimals();
        usdcDm = 10 ** IERC20Metadata(params.usdc).decimals();
        lpUsdcDm = 10 ** IERC20Metadata(params.lpUsdc).decimals();

        usdc.approve(address(poolDepositor), type(uint256).max);
        wmxLpUsdc.approve(address(poolDepositor), type(uint256).max);

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(busd), "Some token not compatible");

        // swap busd to usdc
        uint256 busdBalance = busd.balanceOf(address(this));
        uint256 usdcBalanceOut = WombatLibrary.getAmountOut(
            wombatRouter,
            address(busd),
            address(usdc),
            address(pool),
            busdBalance
        );
        if (usdcBalanceOut > 0) {
            uint256 usdcBalanceOracle = ChainlinkLibrary.convertTokenToToken(
                busdBalance,
                busdDm,
                usdcDm,
                oracleBusd,
                oracleUsdc
            );
            WombatLibrary.swapExactTokensForTokens(
                wombatRouter,
                address(busd),
                address(usdc),
                address(pool),
                busdBalance,
                OvnMath.subBasisPoints(usdcBalanceOracle, swapSlippageBP),
                address(this)
            );
        }

        // get potential deposit amount
        uint256 usdcBalance = usdc.balanceOf(address(this));
        (uint256 lpUsdcAmount,) = poolDepositor.getDepositAmountOut(address(lpUsdc), usdcBalance);
        // deposit
        poolDepositor.deposit(address(lpUsdc), usdcBalance, OvnMath.subBasisPoints(lpUsdcAmount, 1), true);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busd), "Some token not compatible");

        // calculate swap _amount usdc to busd
        uint256 busdAmountForUsdcAmount = WombatLibrary.getAmountOut(
            wombatRouter,
            address(usdc),
            address(busd),
            address(pool),
            _amount
        );
        // get usdcAmount for _amount in busd
        uint256 usdcAmount = _amount * _amount / busdAmountForUsdcAmount;
        // get withdraw amount for 1 LP
        (uint256 usdcAmountOneAsset,) = poolDepositor.getWithdrawAmountOut(address(lpUsdc), lpUsdcDm);
        // add 1bp for smooth withdraw
        uint256 lpUsdcAmount = OvnMath.addBasisPoints(usdcAmount, 1) * lpUsdcDm / usdcAmountOneAsset;

        // withdraw
        poolDepositor.withdraw(address(lpUsdc), lpUsdcAmount, usdcAmount, address(this));

        // swap usdc to busd
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 busdBalanceOut = WombatLibrary.getAmountOut(
            wombatRouter,
            address(usdc),
            address(busd),
            address(pool),
            usdcBalance
        );
        if (busdBalanceOut > 0) {
            uint256 busdBalanceOracle = ChainlinkLibrary.convertTokenToToken(
                usdcBalance,
                usdcDm,
                busdDm,
                oracleUsdc,
                oracleBusd
            );
            WombatLibrary.swapExactTokensForTokens(
                wombatRouter,
                address(usdc),
                address(busd),
                address(pool),
                usdcBalance,
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

        uint256 lpUsdcBalance = wmxLpUsdc.balanceOf(address(this));
        if (lpUsdcBalance > 0) {
            // get withdraw amount
            (uint256 usdcAmount,) = poolDepositor.getWithdrawAmountOut(address(lpUsdc), lpUsdcBalance);
            // withdraw
            poolDepositor.withdraw(address(lpUsdc), lpUsdcBalance, OvnMath.subBasisPoints(usdcAmount, 1), address(this));
        }

        // swap usdc to busd
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 busdBalanceOut = WombatLibrary.getAmountOut(
            wombatRouter,
            address(usdc),
            address(busd),
            address(pool),
            usdcBalance
        );
        if (busdBalanceOut > 0) {
            uint256 busdBalanceOracle = ChainlinkLibrary.convertTokenToToken(
                usdcBalance,
                usdcDm,
                busdDm,
                oracleUsdc,
                oracleBusd
            );
            WombatLibrary.swapExactTokensForTokens(
                wombatRouter,
                address(usdc),
                address(busd),
                address(pool),
                usdcBalance,
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
        uint256 usdcBalance = usdc.balanceOf(address(this));

        uint256 lpUsdcBalance = wmxLpUsdc.balanceOf(address(this));
        if (lpUsdcBalance > 0) {
            (uint256 usdcAmount,) = poolDepositor.getWithdrawAmountOut(address(lpUsdc), lpUsdcBalance);
            usdcBalance += usdcAmount;
        }

        if (usdcBalance > 0) {
            if (nav) {
                busdBalance += ChainlinkLibrary.convertTokenToToken(
                    usdcBalance,
                    usdcDm,
                    busdDm,
                    oracleUsdc,
                    oracleBusd
                );
            } else {
                busdBalance += WombatLibrary.getAmountOut(
                    wombatRouter,
                    address(usdc),
                    address(busd),
                    address(pool),
                    usdcBalance
                );
            }
        }

        return busdBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        uint256 lpUsdcBalance = wmxLpUsdc.balanceOf(address(this));
        if (lpUsdcBalance > 0) {
            wmxLpUsdc.getReward(address(this), false);
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
