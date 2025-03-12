// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DnsVectorStrategyCommon.sol";
import "./DnsVectorStrategyStorageLib.sol";
import "../../Common.sol";
import "../../libraries/InvestableLib.sol";

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

library DnsVectorStrategyInvestmentLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function deposit(uint256 amount, NameValuePair[] calldata) public {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        (, , uint256 maxLoanToValueFactor, , , , , , , ) = strategyStorage
            .aaveProtocolDataProvider
            .getReserveConfigurationData(
                address(strategyStorage.aaveSupplyToken)
            );

        uint256 combinedFixedDecimalFactor = Math.SHORT_FIXED_DECIMAL_FACTOR *
            DnsVectorStrategyCommon.AAVE_FIXED_DECIMAL_FACTOR;

        // without fixed point arithmetic
        // aaveSupplyAllocationInDepositToken = amount / (1 + strategyStorage.safetyFactor
        // * maxLoanToValueFactor)
        uint256 aaveSupplyAllocationInDepositToken = (amount *
            combinedFixedDecimalFactor) /
            (combinedFixedDecimalFactor +
                strategyStorage.safetyFactor *
                maxLoanToValueFactor);

        // without fixed point arithmetic
        // aaveBorrowAllocationUsdcInDepositToken = aaveSupplyAllocationInDepositToken
        // * strategyStorage.safetyFactor * maxLoanToValueFactor)
        uint256 aaveBorrowAllocationUsdcInDepositToken = (aaveSupplyAllocationInDepositToken *
                strategyStorage.safetyFactor *
                maxLoanToValueFactor) / combinedFixedDecimalFactor;

        uint256 poolTokenAllocationInDepositToken = amount -
            aaveSupplyAllocationInDepositToken;
        uint256 avaxUsdcMinimumPrice = strategyStorage.priceOracle.getPrice(
            strategyStorage.aaveBorrowToken,
            false,
            false
        );
        uint256 aaveBorrowAllocationInBorrowToken = InvestableLib
            .convertPricePrecision(
                (aaveBorrowAllocationUsdcInDepositToken *
                    InvestableLib.PRICE_PRECISION_FACTOR) /
                    avaxUsdcMinimumPrice,
                InvestableLib.PRICE_PRECISION_FACTOR,
                (10**strategyStorage.aaveBorrowToken.decimals())
            );

        strategyStorage.aaveSupplyToken.approve(
            address(strategyStorage.aavePool),
            aaveSupplyAllocationInDepositToken
        );

        // assuming aaveSupplyToken == depositToken
        // supplying collateral to Aave
        strategyStorage.aavePool.supply(
            address(strategyStorage.aaveSupplyToken),
            aaveSupplyAllocationInDepositToken,
            address(this),
            0
        );

        // aaveBorrowTokenBalance before borrow
        uint256 aaveBorrowTokenBalanceBeforeBorrow = strategyStorage
            .aaveBorrowToken
            .balanceOf(address(this));

        // borrowing from Aave
        strategyStorage.aavePool.borrow(
            address(strategyStorage.aaveBorrowToken),
            aaveBorrowAllocationInBorrowToken,
            DnsVectorStrategyCommon.VARIABLE_DEBT,
            0,
            address(this)
        );

        // providing liquidity to Pangolin
        // assuming ammPairDepositToken == depositToken
        strategyStorage.ammPairDepositToken.approve(
            address(strategyStorage.pangolinRouter),
            poolTokenAllocationInDepositToken
        );
        strategyStorage.aaveBorrowToken.approve(
            address(strategyStorage.pangolinRouter),
            aaveBorrowAllocationInBorrowToken
        );
        (, , uint256 lpTokenAmountChange) = strategyStorage
            .pangolinRouter
            .addLiquidity(
                address(strategyStorage.ammPairDepositToken),
                address(strategyStorage.aaveBorrowToken),
                poolTokenAllocationInDepositToken,
                aaveBorrowAllocationInBorrowToken,
                0,
                0,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            );

        // staking LP token to Pangolin without locking period
        strategyStorage.pangolinPair.approve(
            address(strategyStorage.pangolinMiniChef),
            lpTokenAmountChange
        );
        strategyStorage.pangolinMiniChef.deposit(
            strategyStorage.pangolinPoolId,
            lpTokenAmountChange,
            address(this)
        );

        // swapping back remnants amount of tokens to depositToken
        // assuming ammPairDepositToken == depositToken as we only
        // swap back aaveBorrowToken
        uint256 aaveBorrowTokenBalanceChange = strategyStorage
            .aaveBorrowToken
            .balanceOf(address(this)) - aaveBorrowTokenBalanceBeforeBorrow;
        if (aaveBorrowTokenBalanceChange != 0) {
            address[] memory path = new address[](2);
            path[0] = address(strategyStorage.aaveBorrowToken);
            path[1] = address(strategyStorage.depositToken);

            uint256 amountOut = SwapServiceLib.getAmountsOut(
                strategyStorage.swapService,
                aaveBorrowTokenBalanceChange,
                path
            )[path.length - 1];

            if (amountOut > 0) {
                SwapServiceLib.swapExactTokensForTokens(
                    strategyStorage.swapService,
                    aaveBorrowTokenBalanceChange,
                    0,
                    path,
                    new uint256[](0)
                );
            }
        }
    }

    function withdraw(
        uint256 amount,
        NameValuePair[] calldata,
        uint256 investmentTokenSupply
    ) public {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        // unstaking liquidity from Pangolin
        uint256 lpAmountChange = strategyStorage.pangolinPair.balanceOf(
            address(this)
        );
        uint256 lpTokenAmount = (DnsVectorStrategyCommon
            .getPangolinLpBalance() * amount) / investmentTokenSupply;
        strategyStorage.pangolinMiniChef.withdraw(
            strategyStorage.pangolinPoolId,
            lpTokenAmount,
            address(this)
        );
        lpAmountChange =
            strategyStorage.pangolinPair.balanceOf(address(this)) -
            lpAmountChange;
        assert(lpTokenAmount == lpAmountChange);

        // withdrawing liquidity from Pangolin
        strategyStorage.pangolinPair.approve(
            address(strategyStorage.pangolinRouter),
            lpTokenAmount
        );
        (
            uint256 ammPairDepositTokenChangeAmount,
            uint256 aaveBorrowTokenChangeAmount
        ) = strategyStorage.pangolinRouter.removeLiquidity(
                address(strategyStorage.ammPairDepositToken),
                address(strategyStorage.aaveBorrowToken),
                lpTokenAmount,
                0,
                0,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            );

        // repay Aave debt
        uint256 vAaveBorrowTokenUserAmount = ((strategyStorage
            .vAaveBorrowToken
            .balanceOf(address(this)) * amount) / investmentTokenSupply);

        // Assumption: the rebalancer works correctly and making sure that
        // the condition of (avax debt) > 2 * (avax supplied to the pool) will never happen.
        // If that condition happens, then withdrawals will be temporarily halted, until rebalancing.
        // One remedy to the above would be to carefully withdraw aaveSupplyToken on the user behalf first,
        // before trying to pay off aaveBorrowToken debt.
        if (aaveBorrowTokenChangeAmount > vAaveBorrowTokenUserAmount) {
            // Pangolin returned more borrowToken than the user needs to pay off debt,
            // swapping the surplus borrowToken back to depositToken
            address[] memory path = new address[](2);
            path[0] = address(strategyStorage.aaveBorrowToken);
            path[1] = address(strategyStorage.depositToken);

            uint256 amountIn = aaveBorrowTokenChangeAmount -
                vAaveBorrowTokenUserAmount;
            uint256 amountOut = SwapServiceLib.getAmountsOut(
                strategyStorage.swapService,
                amountIn,
                path
            )[path.length - 1];
            if (amountOut > 0) {
                SwapServiceLib.swapExactTokensForTokens(
                    strategyStorage.swapService,
                    amountIn,
                    0,
                    path,
                    new uint256[](0)
                );
            }
        } else if (aaveBorrowTokenChangeAmount < vAaveBorrowTokenUserAmount) {
            // Pangolin returned less borrowToken than the user needs to pay off debt,
            // swapping some ammPairDeposit token to borrowToken
            address[] memory path = new address[](2);
            path[0] = address(strategyStorage.ammPairDepositToken);
            path[1] = address(strategyStorage.aaveBorrowToken);

            uint256 amountOut = vAaveBorrowTokenUserAmount -
                aaveBorrowTokenChangeAmount;
            SwapServiceLib.swapTokensForExactTokens(
                strategyStorage.swapService,
                amountOut,
                ammPairDepositTokenChangeAmount,
                path,
                new uint256[](0)
            );
            // assuming ammPairDepositToken == depositToken
        }
        strategyStorage.aaveBorrowToken.approve(
            address(strategyStorage.aavePool),
            vAaveBorrowTokenUserAmount
        );
        uint256 repayed = strategyStorage.aavePool.repay(
            address(strategyStorage.aaveBorrowToken),
            vAaveBorrowTokenUserAmount,
            DnsVectorStrategyCommon.VARIABLE_DEBT,
            address(this)
        );
        assert(repayed == vAaveBorrowTokenUserAmount);

        // withdraw from Aave supply
        uint256 aAaveSupplyTokenUserAmount = ((strategyStorage
            .aAaveSupplyToken
            .balanceOf(address(this)) * amount) / investmentTokenSupply);
        uint256 aaveSupplyTokenChangeAmount = strategyStorage
            .aaveSupplyToken
            .balanceOf(address(this));
        strategyStorage.aavePool.withdraw(
            address(strategyStorage.aaveSupplyToken),
            aAaveSupplyTokenUserAmount,
            address(this)
        );
        aaveSupplyTokenChangeAmount =
            strategyStorage.aaveSupplyToken.balanceOf(address(this)) -
            aaveSupplyTokenChangeAmount;
        assert(aaveSupplyTokenChangeAmount == aAaveSupplyTokenUserAmount);
    }

    function reapReward(
        NameValuePair[] calldata /*params*/
    ) external {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        uint256 pngTokenBalanceChange = strategyStorage.pngToken.balanceOf(
            address(this)
        );

        // reaping reward from Pangolin
        strategyStorage.pangolinMiniChef.harvest(
            strategyStorage.pangolinPoolId,
            address(this)
        );

        pngTokenBalanceChange =
            strategyStorage.pngToken.balanceOf(address(this)) -
            pngTokenBalanceChange;

        address[] memory path = new address[](3);
        path[0] = address(strategyStorage.pngToken);
        path[1] = address(strategyStorage.aaveBorrowToken);
        path[2] = address(strategyStorage.depositToken);
        SwapServiceLib.swapExactTokensForTokens(
            strategyStorage.swapService,
            pngTokenBalanceChange,
            0,
            path,
            new uint256[](0)
        );
    }

    function repayDebt(uint256 pangolinPairAmount, NameValuePair[] calldata)
        external
    {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        // unstaking liquidity from Pangolin
        uint256 lpAmountChange = strategyStorage.pangolinPair.balanceOf(
            address(this)
        );
        strategyStorage.pangolinMiniChef.withdraw(
            strategyStorage.pangolinPoolId,
            pangolinPairAmount,
            address(this)
        );
        lpAmountChange =
            strategyStorage.pangolinPair.balanceOf(address(this)) -
            lpAmountChange;
        assert(pangolinPairAmount == lpAmountChange);

        // withdrawing liquidity from Pangolin
        uint256 aaveBorrowTokenBefore = strategyStorage
            .aaveBorrowToken
            .balanceOf(address(this));

        strategyStorage.pangolinPair.approve(
            address(strategyStorage.pangolinRouter),
            lpAmountChange
        );
        (uint256 aaveSupplyTokenAmountChange, ) = strategyStorage
            .pangolinRouter
            .removeLiquidity(
                address(strategyStorage.ammPairDepositToken),
                address(strategyStorage.aaveBorrowToken),
                lpAmountChange,
                0,
                0,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            );

        // converting aaveSupplyToken to aaveBorrowToken
        address[] memory path = new address[](2);
        path[0] = address(strategyStorage.aaveSupplyToken);
        path[1] = address(strategyStorage.aaveBorrowToken);
        SwapServiceLib.swapExactTokensForTokens(
            strategyStorage.swapService,
            aaveSupplyTokenAmountChange,
            0,
            path,
            new uint256[](0)
        );
        uint256 aaveBorrowTokenAmountChange = strategyStorage
            .aaveBorrowToken
            .balanceOf(address(this)) - aaveBorrowTokenBefore;

        // repay aave debt
        strategyStorage.aaveBorrowToken.approve(
            address(strategyStorage.aavePool),
            aaveBorrowTokenAmountChange
        );
        uint256 repayed = strategyStorage.aavePool.repay(
            address(strategyStorage.aaveBorrowToken),
            aaveBorrowTokenAmountChange,
            DnsVectorStrategyCommon.VARIABLE_DEBT,
            address(this)
        );
        assert(repayed == aaveBorrowTokenAmountChange);
    }

    function increaseDebt(
        uint256 aaveBorrowTokenAmount,
        NameValuePair[] calldata params
    ) external {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        // borrow more aaveBorrowTokenAmount
        strategyStorage.aavePool.borrow(
            address(strategyStorage.aaveBorrowToken),
            aaveBorrowTokenAmount,
            DnsVectorStrategyCommon.VARIABLE_DEBT,
            0,
            address(this)
        );

        // swap aaveBorrowTokenAmount to depositToken
        uint256 depositTokenBalanceChange = strategyStorage
            .depositToken
            .balanceOf(address(this));
        // assuming aaveBorrowToken != depositToken
        address[] memory path = new address[](2);
        path[0] = address(strategyStorage.aaveBorrowToken);
        path[1] = address(strategyStorage.depositToken);
        SwapServiceLib.swapExactTokensForTokens(
            strategyStorage.swapService,
            aaveBorrowTokenAmount,
            0,
            path,
            new uint256[](0)
        );
        depositTokenBalanceChange =
            strategyStorage.depositToken.balanceOf(address(this)) -
            depositTokenBalanceChange;

        // reinvest into the strategy
        deposit(depositTokenBalanceChange, params);
    }

    function decreaseSupply(
        uint256 aaveSupplyTokenAmount,
        NameValuePair[] calldata params
    ) external {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        // withdraw aaveSupplyToken from aave
        uint256 aaveSupplyTokenAmountChange = strategyStorage
            .aaveSupplyToken
            .balanceOf(address(this));
        strategyStorage.aavePool.withdraw(
            address(strategyStorage.aaveSupplyToken),
            aaveSupplyTokenAmount,
            address(this)
        );
        aaveSupplyTokenAmountChange =
            strategyStorage.aaveSupplyToken.balanceOf(address(this)) -
            aaveSupplyTokenAmountChange;
        assert(aaveSupplyTokenAmount == aaveSupplyTokenAmountChange);

        // reinvest into the strategy
        // assuming aaveSupplyToken == depositToken
        deposit(aaveSupplyTokenAmountChange, params);
    }

    function migrate() external {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        // Migration from Vector and TraderJoe to Pangolin consists of seven steps.
        // 0. Withdraw all TraderJoe LP tokens from Vector.
        // 1. Remove all liquidity from TraderJoe.
        // 2. Swap only minimum amount to match Pangolin's pool assets ratio.
        // 3. Add all liquidity to Pangolin.
        // 4. Deposit LP token to Pangolin.
        // 5. Swap remaining `AaveBorrowToken` to `DepositToken`.
        // 6. Check if valuation after migration is greater than or equal to minValuation. (This is done by DnsVectorStrategy contract.)

        // 0. Withdraw all TraderJoe LP tokens from Vector.
        uint256 lpBalance = strategyStorage.vectorPoolHelperJoe.balanceOf(
            address(this)
        );

        strategyStorage.vectorPoolHelperJoe.withdraw(lpBalance);

        // 1. Remove all liquidity from TraderJoe.
        uint256 ammPairDepositTokenAmountBefore = strategyStorage
            .ammPairDepositToken
            .balanceOf(address(this));
        uint256 aaveBorrowTokenAmountBefore = strategyStorage
            .aaveBorrowToken
            .balanceOf(address(this));

        strategyStorage.traderJoePair.approve(
            address(strategyStorage.traderJoeRouter),
            lpBalance
        );
        strategyStorage.traderJoeRouter.removeLiquidity(
            address(strategyStorage.ammPairDepositToken),
            address(strategyStorage.aaveBorrowToken),
            lpBalance,
            0,
            0,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        );

        uint256 ammPairDepositTokenAmountIn = strategyStorage
            .ammPairDepositToken
            .balanceOf(address(this)) - ammPairDepositTokenAmountBefore;
        uint256 aaveBorrowTokenAmountIn = strategyStorage
            .aaveBorrowToken
            .balanceOf(address(this)) - aaveBorrowTokenAmountBefore;

        // 2. Swap only minimum amount to match Pangolin's pool assets ratio.
        (
            uint256 ammPairDepositTokenAmountDesired,
            uint256 aaveBorrowTokenAmountDesired
        ) = __prepareTokens(
                ammPairDepositTokenAmountIn,
                aaveBorrowTokenAmountIn
            );

        // 3. Add all liquidity to Pangolin.
        // assuming ammPairDepositToken == depositToken
        strategyStorage.ammPairDepositToken.approve(
            address(strategyStorage.pangolinRouter),
            ammPairDepositTokenAmountDesired
        );
        strategyStorage.aaveBorrowToken.approve(
            address(strategyStorage.pangolinRouter),
            aaveBorrowTokenAmountDesired
        );
        (, , uint256 lpTokenAmountChange) = strategyStorage
            .pangolinRouter
            .addLiquidity(
                address(strategyStorage.ammPairDepositToken),
                address(strategyStorage.aaveBorrowToken),
                ammPairDepositTokenAmountDesired,
                aaveBorrowTokenAmountDesired,
                0,
                0,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            );

        // 4. Deposit LP token to Pangolin.
        strategyStorage.pangolinPair.approve(
            address(strategyStorage.pangolinMiniChef),
            lpTokenAmountChange
        );
        strategyStorage.pangolinMiniChef.deposit(
            strategyStorage.pangolinPoolId,
            lpTokenAmountChange,
            address(this)
        );

        // 5. Swap remaining `AaveBorrowToken` to `DepositToken`.
        uint256 aaveBorrowTokenAmountAfter = strategyStorage
            .aaveBorrowToken
            .balanceOf(address(this));

        if (aaveBorrowTokenAmountAfter > aaveBorrowTokenAmountBefore) {
            address[] memory path = new address[](2);
            path[0] = address(strategyStorage.aaveBorrowToken);
            path[1] = address(strategyStorage.depositToken);

            uint256 aaveBorrowTokenAmountRemaining = aaveBorrowTokenAmountAfter -
                    aaveBorrowTokenAmountBefore;

            uint256 amountOut = SwapServiceLib.getAmountsOut(
                strategyStorage.swapService,
                aaveBorrowTokenAmountRemaining,
                path
            )[path.length - 1];

            if (amountOut > 0) {
                SwapServiceLib.swapExactTokensForTokens(
                    strategyStorage.swapService,
                    aaveBorrowTokenAmountRemaining,
                    0,
                    path,
                    new uint256[](0)
                );
            }
        }
    }

    function __prepareTokens(
        uint256 ammPairDepositTokenAmountIn,
        uint256 aaveBorrowTokenAmountIn
    )
        private
        returns (
            uint256 ammPairDepositTokenAmountDesired,
            uint256 aaveBorrowTokenAmountDesired
        )
    {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        // Calculate which token we have more than we need.
        (
            uint256 ammPairDepositTokenReserve,
            uint256 aaveBorrowTokenReserve
        ) = DnsVectorStrategyCommon.getPangolinLpReserve(
                address(strategyStorage.ammPairDepositToken),
                address(strategyStorage.aaveBorrowToken)
            );

        bool swapAmmPairDepositTokenToAaveBorrowToken;
        bool swapAaveBorrowTokenToAmmPairDepositToken;

        uint256 ammPairDepositTokenDesiredMulByReserve = ammPairDepositTokenAmountIn *
                aaveBorrowTokenReserve;
        uint256 aaveBorrowTokenDesiredMulByReserve = aaveBorrowTokenAmountIn *
            ammPairDepositTokenReserve;

        if (
            ammPairDepositTokenDesiredMulByReserve >
            aaveBorrowTokenDesiredMulByReserve
        ) {
            swapAmmPairDepositTokenToAaveBorrowToken = true;
        } else if (
            ammPairDepositTokenDesiredMulByReserve <
            aaveBorrowTokenDesiredMulByReserve
        ) {
            swapAaveBorrowTokenToAmmPairDepositToken = true;
        }

        address[] memory path = new address[](2);
        uint256 amountToSwap;

        // Calculate only necessary amount to swap to match Pangolin's pool assets ratio.
        if (swapAmmPairDepositTokenToAaveBorrowToken) {
            uint256 aaveBorrowTokenPriceInAmmPairDepositToken = strategyStorage
                .priceOracle
                .getPrice(strategyStorage.aaveBorrowToken, true, false);

            amountToSwap =
                (ammPairDepositTokenDesiredMulByReserve -
                    aaveBorrowTokenDesiredMulByReserve) /
                (aaveBorrowTokenPriceInAmmPairDepositToken *
                    ammPairDepositTokenReserve +
                    aaveBorrowTokenReserve);

            path[0] = address(strategyStorage.ammPairDepositToken);
            path[1] = address(strategyStorage.aaveBorrowToken);
        } else if (swapAaveBorrowTokenToAmmPairDepositToken) {
            uint256 ammPairDepositTokenPriceInAaveBorrowToken = 10 **
                (InvestableLib.PRICE_PRECISION_DIGITS * 2) /
                strategyStorage.priceOracle.getPrice(
                    strategyStorage.aaveBorrowToken,
                    true,
                    false
                );

            amountToSwap =
                (aaveBorrowTokenDesiredMulByReserve -
                    ammPairDepositTokenDesiredMulByReserve) /
                (ammPairDepositTokenPriceInAaveBorrowToken *
                    aaveBorrowTokenReserve +
                    ammPairDepositTokenReserve);

            path[0] = address(strategyStorage.aaveBorrowToken);
            path[1] = address(strategyStorage.ammPairDepositToken);
        }

        uint256 amountOut = SwapServiceLib.getAmountsOut(
            strategyStorage.swapService,
            amountToSwap,
            path
        )[path.length - 1];

        // Return desired amounts of tokens.
        if (amountOut > 0) {
            SwapServiceLib.swapExactTokensForTokens(
                strategyStorage.swapService,
                amountToSwap,
                0,
                path,
                new uint256[](0)
            );

            if (swapAmmPairDepositTokenToAaveBorrowToken) {
                ammPairDepositTokenAmountDesired =
                    ammPairDepositTokenAmountIn -
                    amountToSwap;
                aaveBorrowTokenAmountDesired =
                    aaveBorrowTokenAmountIn +
                    amountOut;
            } else if (swapAaveBorrowTokenToAmmPairDepositToken) {
                ammPairDepositTokenAmountDesired =
                    ammPairDepositTokenAmountIn +
                    amountOut;
                aaveBorrowTokenAmountDesired =
                    aaveBorrowTokenAmountIn -
                    amountToSwap;
            }
        } else {
            ammPairDepositTokenAmountDesired = ammPairDepositTokenAmountIn;
            aaveBorrowTokenAmountDesired = aaveBorrowTokenAmountIn;
        }
    }
}
