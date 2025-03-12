// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { NameValuePair } from "../../../Common.sol";
import { InvestableDesc } from "../../../interfaces/IPortfolio.sol";
import { IInvestable } from "../../../interfaces/IInvestable.sol";
import { Math } from "../../../libraries/Math.sol";

library PortfolioBaseFeeLib {
    enum FeeType {
        Deposit,
        Withdrawal,
        Performance,
        Management
    }

    function calculateEmbeddedFeeActualAllocation(
        FeeType feeType,
        NameValuePair[] calldata params,
        InvestableDesc[] storage investableDescs
    ) external view returns (uint24) {
        uint256 embeddedFee;
        uint256 totalEquity;
        uint256 investableDescsLength = investableDescs.length;
        // calculating current equity for investables
        uint256[] memory currentInvestableEquities = new uint256[](
            investableDescs.length
        );
        for (uint256 i = 0; i < investableDescsLength; i++) {
            IInvestable embeddedInvestable = investableDescs[i].investable;
            if (embeddedInvestable.getInvestmentTokenSupply() != 0) {
                currentInvestableEquities[i] =
                    (embeddedInvestable.getEquityValuation(false, false) *
                        embeddedInvestable.getInvestmentTokenBalanceOf(
                            address(this)
                        )) /
                    embeddedInvestable.getInvestmentTokenSupply();
                totalEquity += currentInvestableEquities[i];
            }
        }

        // no prior investment into any of the strategies by the portfolio
        if (totalEquity == 0) {
            return
                calculateEmbeddedFeeTargetAllocation(
                    feeType,
                    params,
                    investableDescs
                );
        }
        // there is at least one strategy with investment by the portfolio
        else {
            for (uint256 i = 0; i < investableDescsLength; i++) {
                IInvestable embeddedInvestable = investableDescs[i].investable;
                embeddedFee +=
                    (uint256(
                        (feeType == FeeType.Withdrawal)
                            ? embeddedInvestable.getTotalWithdrawalFee(params)
                            : (
                                (feeType == FeeType.Management)
                                    ? embeddedInvestable.getTotalManagementFee(
                                        params
                                    )
                                    : embeddedInvestable.getTotalPerformanceFee(
                                        params
                                    )
                            )
                    ) * currentInvestableEquities[i]) /
                    totalEquity;
            }
            return uint24(embeddedFee);
        }
    }

    function calculateEmbeddedFeeTargetAllocation(
        FeeType feeType,
        NameValuePair[] calldata params,
        InvestableDesc[] storage investableDescs
    ) public view returns (uint24) {
        uint256 embeddedFee;
        uint256 investableDescsLength = investableDescs.length;
        for (uint256 i = 0; i < investableDescsLength; i++) {
            IInvestable embeddedInvestable = investableDescs[i].investable;
            embeddedFee +=
                uint256(
                    (feeType == FeeType.Deposit)
                        ? embeddedInvestable.getTotalDepositFee(params)
                        : (
                            (feeType == FeeType.Withdrawal)
                                ? embeddedInvestable.getTotalWithdrawalFee(
                                    params
                                )
                                : (
                                    (feeType == FeeType.Performance)
                                        ? embeddedInvestable
                                            .getTotalPerformanceFee(params)
                                        : embeddedInvestable
                                            .getTotalManagementFee(params)
                                )
                        )
                ) *
                investableDescs[i].allocationPercentage;
        }
        return uint24(embeddedFee / Math.SHORT_FIXED_DECIMAL_FACTOR / 100);
    }
}
