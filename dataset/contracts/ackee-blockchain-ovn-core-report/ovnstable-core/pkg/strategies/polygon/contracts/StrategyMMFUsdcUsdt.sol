// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/Synapse.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/MMF.sol";

contract StrategyMMFUsdcUsdt is Strategy {

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IERC20 public mmfToken;

    IUniswapV2Router02 public meerkatRouter02;
    IUniswapV2Pair public meerkatPair;
    IMasterMeerkat public masterMeerkat;
    uint256 public pid;

    ISwap public synapseSwap;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleUsdt;

    uint256 public usdcTokenDenominator;
    uint256 public usdtTokenDenominator;


    // --- events

    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdcToken;
        address usdtToken;
        address mmfToken;
        address meerkatRouter02;
        address meerkatPair;
        address masterMeerkat;
        uint256 pid;
        address synapseSwap;
        address oracleUsdc;
        address oracleUsdt;
    }


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdcToken = IERC20(params.usdcToken);
        usdtToken = IERC20(params.usdtToken);
        mmfToken = IERC20(params.mmfToken);

        meerkatRouter02 = IUniswapV2Router02(params.meerkatRouter02);
        meerkatPair = IUniswapV2Pair(params.meerkatPair);
        masterMeerkat = IMasterMeerkat(params.masterMeerkat);
        pid = params.pid;

        synapseSwap = ISwap(params.synapseSwap);

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleUsdt = IPriceFeed(params.oracleUsdt);

        usdcTokenDenominator = 10 ** IERC20Metadata(params.usdcToken).decimals();
        usdtTokenDenominator = 10 ** IERC20Metadata(params.usdcToken).decimals();

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveUsdc, uint256 reserveUsdt,) = meerkatPair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveUsdt > 10 ** 3, 'Liquidity meerkatPair reserves too low');

        // count amount usdt to swap
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        uint256 amountUsdcFromUsdt;
        if (usdtBalance > 0) {
            amountUsdcFromUsdt = SynapseLibrary.calculateSwap(
                synapseSwap,
                address(usdtToken),
                address(usdcToken),
                usdtBalance
            );
        }
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 amountUsdcToSwap = SynapseLibrary.getAmount0(
            synapseSwap,
            address(usdcToken),
            address(usdtToken),
            usdcBalance - amountUsdcFromUsdt,
            reserveUsdc,
            reserveUsdt,
            usdcTokenDenominator,
            usdtTokenDenominator,
            1
        );

        // swap usdc to usdt
        SynapseLibrary.swap(
            synapseSwap,
            address(usdcToken),
            address(usdtToken),
            amountUsdcToSwap
        );

        // add liquidity
        usdcBalance = usdcToken.balanceOf(address(this));
        usdtBalance = usdtToken.balanceOf(address(this));
        usdcToken.approve(address(meerkatRouter02), usdcBalance);
        usdtToken.approve(address(meerkatRouter02), usdtBalance);
        meerkatRouter02.addLiquidity(
            address(usdcToken),
            address(usdtToken),
            usdcBalance,
            usdtBalance,
            usdcBalance * 99 / 100,
            usdtBalance * 99 / 100,
            address(this),
            block.timestamp
        );

        // deposit lpTokens to masterMeerkat
        uint256 lpBalance = meerkatPair.balanceOf(address(this));
        meerkatPair.approve(address(masterMeerkat), type(uint256).max);
        // send address(0x0) for referrer
        masterMeerkat.deposit(pid, lpBalance, address(0x0));
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveUsdc, uint256 reserveUsdt,) = meerkatPair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveUsdt > 10 ** 3, 'Liquidity meerkatPair reserves too low');

        (uint256 lpBalanceUser, ) = masterMeerkat.userInfo(pid, address(this));
        if (lpBalanceUser > 0) {
            // count amount to unstake
            uint256 totalLpBalance = meerkatPair.totalSupply();
            uint256 lpBalanceToWithdraw = SynapseLibrary.getAmountLpTokens(
                synapseSwap,
                address(usdcToken),
                address(usdtToken),
                // add 10 to _amount for smooth withdraw
                _amount + 10,
                totalLpBalance,
                reserveUsdc,
                reserveUsdt,
                usdcTokenDenominator,
                usdtTokenDenominator,
                1
            );
            if (lpBalanceToWithdraw > lpBalanceUser) {
                lpBalanceToWithdraw = lpBalanceUser;
            }

            // withdraw lpTokens from masterMeerkat
            masterMeerkat.withdraw(pid, lpBalanceToWithdraw);

            // remove liquidity
            uint256 amountOutUsdcMin = reserveUsdc * lpBalanceToWithdraw / totalLpBalance;
            uint256 amountOutUsdtMin = reserveUsdt * lpBalanceToWithdraw / totalLpBalance;
            meerkatPair.approve(address(meerkatRouter02), lpBalanceToWithdraw);
            meerkatRouter02.removeLiquidity(
                meerkatPair.token0(),
                meerkatPair.token1(),
                lpBalanceToWithdraw,
                amountOutUsdcMin * 99 / 100,
                amountOutUsdtMin * 99 / 100,
                address(this),
                block.timestamp
            );
        }

        // swap usdt to usdc
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            uint256 amountUsdcFromUsdt = SynapseLibrary.calculateSwap(
                synapseSwap,
                address(usdtToken),
                address(usdcToken),
                usdtBalance
            );

            if (amountUsdcFromUsdt > 0) {
                SynapseLibrary.swap(
                    synapseSwap,
                    address(usdtToken),
                    address(usdcToken),
                    usdtBalance
                );
            }
        }

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 lpBalanceUser, ) = masterMeerkat.userInfo(pid, address(this));
        if (lpBalanceUser > 0) {
            // withdraw lpTokens from masterMeerkat
            masterMeerkat.withdraw(pid, lpBalanceUser);

            // remove liquidity
            (uint256 reserveUsdc, uint256 reserveUsdt,) = meerkatPair.getReserves();
            uint256 totalLpBalance = meerkatPair.totalSupply();
            uint256 amountOutUsdcMin = reserveUsdc * lpBalanceUser / totalLpBalance;
            uint256 amountOutUsdtMin = reserveUsdt * lpBalanceUser / totalLpBalance;

            meerkatPair.approve(address(meerkatRouter02), lpBalanceUser);
            meerkatRouter02.removeLiquidity(
                meerkatPair.token0(),
                meerkatPair.token1(),
                lpBalanceUser,
                amountOutUsdcMin * 99 / 100,
                amountOutUsdtMin * 99 / 100,
                address(this),
                block.timestamp
            );
        }

        // swap usdt to usdc
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            uint256 amountUsdcFromUsdt = SynapseLibrary.calculateSwap(
                synapseSwap,
                address(usdtToken),
                address(usdcToken),
                usdtBalance
            );

            if (amountUsdcFromUsdt > 0) {
                SynapseLibrary.swap(
                    synapseSwap,
                    address(usdtToken),
                    address(usdcToken),
                    usdtBalance
                );
            }
        }

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 usdtBalance = usdtToken.balanceOf(address(this));

        (uint256 lpBalance, ) = masterMeerkat.userInfo(pid, address(this));
        if (lpBalance > 0) {
            uint256 totalLpBalance = meerkatPair.totalSupply();
            (uint256 reserveUsdc, uint256 reserveUsdt,) = meerkatPair.getReserves();
            usdcBalance += reserveUsdc * lpBalance / totalLpBalance;
            usdtBalance += reserveUsdt * lpBalance / totalLpBalance;
        }

        uint256 usdcBalanceFromUsdt;
        if (usdtBalance > 0) {
            if (nav) {
                uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
                uint256 priceUsdt = uint256(oracleUsdt.latestAnswer());
                usdcBalanceFromUsdt = (usdtBalance * usdcTokenDenominator * priceUsdt) / (usdtTokenDenominator * priceUsdc);
            } else {
                usdcBalanceFromUsdt = SynapseLibrary.calculateSwap(
                    synapseSwap,
                    address(usdtToken),
                    address(usdcToken),
                    usdtBalance
                );
            }
        }

        return usdcBalance + usdcBalanceFromUsdt;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        // claim rewards
        (uint256 lpBalance, ) = masterMeerkat.userInfo(pid, address(this));
        if (lpBalance > 0) {
            // send 0 to claim rewards and send address(0x0) for referrer
            masterMeerkat.deposit(pid, 0, address(0x0));
        }

        // sell rewards
        uint256 totalUsdc;

        uint256 mmfBalance = mmfToken.balanceOf(address(this));
        if (mmfBalance > 0) {
            uint256 amountOutMin = UniswapV2Library.getAmountsOut(
                meerkatRouter02,
                address(mmfToken),
                address(usdcToken),
                mmfBalance
            );

            if (amountOutMin > 0) {
                uint256 mmfUsdc = UniswapV2Library.swapExactTokensForTokens(
                    meerkatRouter02,
                    address(mmfToken),
                    address(usdcToken),
                    mmfBalance,
                    amountOutMin * 99 / 100,
                    address(this)
                );
                totalUsdc += mmfUsdc;
            }
        }

        if (totalUsdc > 0) {
            usdcToken.transfer(_to, totalUsdc);
        }

        return totalUsdc;
    }

}
