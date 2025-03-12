// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IInvestable } from "../../../interfaces/IInvestable.sol";
import { IPriceOracle } from "../../../interfaces/IPriceOracle.sol";
import { NameValuePair } from "../../../Common.sol";
import { Math } from "../../../libraries/Math.sol";
import { InvestableLib } from "../../../libraries/InvestableLib.sol";
import { InvestableDesc } from "../../../interfaces/IPortfolio.sol";
import { PortfolioBaseAumLib } from "./PortfolioBaseAumLib.sol";
import { IInvestmentToken } from "../../../interfaces/IInvestmentToken.sol";
import { InvestmentLimitLib } from "../../InvestmentLimitUpgradeable.sol";
import { IERC20UpgradeableExt } from "../../../interfaces/IERC20UpgradeableExt.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

struct DepositArgs {
    uint256 depositTokenAmountIn;
    uint256 minimumDepositTokenAmountOut;
    address investmentTokenReceiver;
    IERC20UpgradeableExt depositToken;
    IInvestmentToken investmentToken;
    address msgSender;
    uint256 totalInvestmentLimit;
    uint256 investmentLimitPerAddress;
    bool depositTokenAlreadyTransferred;
    IPriceOracle priceOracle;
}

struct WithdrawArgs {
    uint256 investmentTokenAmountIn;
    uint256 minimumDepositTokenAmountOut;
    address depositTokenReceiver;
    IERC20UpgradeableExt depositToken;
    IInvestmentToken investmentToken;
    address msgSender;
    bool shouldTransferDepositTokens;
}

library PortfolioBaseInvestmentLib {
    using SafeERC20Upgradeable for IERC20UpgradeableExt;

    function deposit(
        DepositArgs memory depositArgs,
        InvestableDesc[] storage investableDescs,
        NameValuePair[] calldata params
    ) external {
        if (depositArgs.depositTokenAmountIn == 0)
            revert IInvestable.ZeroAmountDeposited();
        if (depositArgs.investmentTokenReceiver == address(0))
            revert IInvestable.ZeroInvestmentTokenReceiver();

        // check investment limits
        // the underlying defi protocols might take fees, but for limit check we can safely ignore it
        uint256 equityValuationBeforeInvestment = PortfolioBaseAumLib
            .getEquityValuation(true, false, investableDescs);
        uint256 userEquity;
        uint256 investmentTokenSupply = depositArgs
            .investmentToken
            .totalSupply();
        if (investmentTokenSupply != 0) {
            uint256 investmentTokenBalance = depositArgs
                .investmentToken
                .balanceOf(depositArgs.investmentTokenReceiver);
            userEquity =
                (equityValuationBeforeInvestment * investmentTokenBalance) /
                investmentTokenSupply;
        }
        InvestmentLimitLib.checkTotalInvestmentLimit(
            depositArgs.depositTokenAmountIn,
            equityValuationBeforeInvestment,
            depositArgs.totalInvestmentLimit
        );
        InvestmentLimitLib.checkInvestmentLimitPerAddress(
            depositArgs.depositTokenAmountIn,
            userEquity,
            depositArgs.investmentLimitPerAddress
        );

        if (!depositArgs.depositTokenAlreadyTransferred) {
            // transfering deposit tokens from the user
            depositArgs.depositToken.safeTransferFrom(
                depositArgs.msgSender,
                address(this),
                depositArgs.depositTokenAmountIn
            );
        }

        for (uint256 i = 0; i < investableDescs.length; i++) {
            uint256 embeddedAmount = (depositArgs.depositTokenAmountIn *
                investableDescs[i].allocationPercentage) /
                Math.SHORT_FIXED_DECIMAL_FACTOR /
                100;
            if (embeddedAmount == 0) continue;
            depositArgs.depositToken.approve(
                address(investableDescs[i].investable),
                embeddedAmount
            );
            investableDescs[i].investable.deposit(
                embeddedAmount,
                0,
                address(this),
                params
            );
        }

        // calculating the actual amount invested into the defi protocol
        uint256 equityValuationAfterInvestment = PortfolioBaseAumLib
            .getEquityValuation(true, false, investableDescs);
        uint256 actualInvested = equityValuationAfterInvestment -
            equityValuationBeforeInvestment;
        if (actualInvested == 0) revert IInvestable.ZeroAmountInvested();
        if (actualInvested < depositArgs.minimumDepositTokenAmountOut)
            revert IInvestable.TooSmallDepositTokenAmountOut();

        // 1. Minting should be based on the actual amount invested versus the deposited amount
        //    to take defi fees and losses into consideration.
        // 2. Calling  depositToken.decimals() should be cached into a state variable, but that
        //    would require us to update all previous contracts.
        depositArgs.investmentToken.mint(
            depositArgs.investmentTokenReceiver,
            InvestableLib.calculateMintAmount(
                equityValuationBeforeInvestment,
                actualInvested,
                investmentTokenSupply
            )
        );
    }

    function withdraw(
        WithdrawArgs memory withdrawArgs,
        InvestableDesc[] storage investableDescs,
        NameValuePair[] calldata params
    ) external {
        if (withdrawArgs.investmentTokenAmountIn == 0)
            revert IInvestable.ZeroAmountWithdrawn();
        if (withdrawArgs.depositTokenReceiver == address(0))
            revert IInvestable.ZeroDepositTokenReceiver();

        // transferring investment tokens from the caller
        uint256 withdrawnDepositTokenAmount = withdrawArgs
            .depositToken
            .balanceOf(address(this));
        // withdrawing from underlying investables
        uint256 investmentTokenSupply = withdrawArgs
            .investmentToken
            .totalSupply();
        for (uint256 i = 0; i < investableDescs.length; i++) {
            IInvestable embeddedInvestable = investableDescs[i].investable;
            uint256 embeddedTokenAmountToBurn = (embeddedInvestable
                .getInvestmentTokenBalanceOf(address(this)) *
                withdrawArgs.investmentTokenAmountIn) / investmentTokenSupply;
            if (embeddedTokenAmountToBurn == 0) continue;
            embeddedInvestable.getInvestmentToken().approve(
                address(embeddedInvestable),
                embeddedTokenAmountToBurn
            );
            embeddedInvestable.withdraw(
                embeddedTokenAmountToBurn,
                0,
                address(this),
                params
            );
        }
        // checking whether enough deposit token was withdrawn
        withdrawnDepositTokenAmount =
            withdrawArgs.depositToken.balanceOf(address(this)) -
            withdrawnDepositTokenAmount;
        if (
            withdrawnDepositTokenAmount <
            withdrawArgs.minimumDepositTokenAmountOut
        ) revert IInvestable.TooSmallDepositTokenAmountOut();
        // burning investment tokens
        withdrawArgs.investmentToken.burnFrom(
            withdrawArgs.msgSender,
            withdrawArgs.investmentTokenAmountIn
        );

        if (withdrawArgs.shouldTransferDepositTokens) {
            //transferring deposit tokens to the depositTokenReceiver
            withdrawArgs.depositToken.safeTransfer(
                withdrawArgs.depositTokenReceiver,
                withdrawnDepositTokenAmount
            );
        }
    }
}
