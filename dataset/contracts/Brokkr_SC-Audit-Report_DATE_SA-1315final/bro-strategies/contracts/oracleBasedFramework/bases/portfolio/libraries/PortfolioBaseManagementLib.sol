// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IInvestable } from "../../../interfaces/IInvestable.sol";
import { IPortfolio } from "../../../interfaces/IPortfolio.sol";
import { InvestableDesc } from "../../../interfaces/IPortfolio.sol";
import { NameValuePair } from "../../../Common.sol";
import { Math } from "../../../libraries/Math.sol";
import { IERC20UpgradeableExt } from "../../../interfaces/IERC20UpgradeableExt.sol";
import { IInvestmentToken } from "../../../interfaces/IInvestmentToken.sol";

struct RebalanceArgs {
    uint256 minimumDepositTokenAmountOut;
    IERC20UpgradeableExt depositToken;
    IInvestmentToken investmentToken;
}

library PortfolioBaseManagementLib {
    // workaround for 'stack too deep' error
    struct RebalanceLocalVars {
        uint256 totalEquityBeforeRebalance;
        uint256 totalEquityAfterRebalance;
        uint256 withdrawnAmount;
        uint256 remainingAmount;
    }

    function _rebalance(
        RebalanceArgs memory rebalanceArgs,
        InvestableDesc[] storage investableDescs,
        NameValuePair[][] calldata depositParams,
        NameValuePair[][] calldata withdrawParams
    ) external {
        RebalanceLocalVars memory rebalanceLocalVars;

        // calculating current equity for investables
        uint256 investableDescsLength = investableDescs.length;
        uint256[] memory currentInvestableEquities;
        (
            currentInvestableEquities,
            rebalanceLocalVars.totalEquityBeforeRebalance
        ) = getTotalEquity(investableDescs);

        if (rebalanceLocalVars.totalEquityBeforeRebalance == 0) {
            return;
        }
        // calculating target equities for investables
        uint256[] memory targetInvestableEquities = new uint256[](
            investableDescsLength
        );
        for (uint256 i = 0; i < investableDescsLength; i++) {
            targetInvestableEquities[i] =
                (rebalanceLocalVars.totalEquityBeforeRebalance *
                    investableDescs[i].allocationPercentage) /
                Math.SHORT_FIXED_DECIMAL_FACTOR /
                100;
        }
        // withdrawing from investables that are above the target equity
        rebalanceLocalVars.withdrawnAmount = rebalanceArgs
            .depositToken
            .balanceOf(address(this));
        for (uint256 i = 0; i < investableDescsLength; i++) {
            IInvestable embeddedInvestable = investableDescs[i].investable;
            if (currentInvestableEquities[i] > targetInvestableEquities[i]) {
                uint256 withdrawAmount = embeddedInvestable
                    .getInvestmentTokenBalanceOf(address(this)) -
                    (embeddedInvestable.getInvestmentTokenBalanceOf(
                        address(this)
                    ) * targetInvestableEquities[i]) /
                    currentInvestableEquities[i];
                embeddedInvestable.getInvestmentToken().approve(
                    address(embeddedInvestable),
                    withdrawAmount
                );
                embeddedInvestable.withdraw(
                    withdrawAmount,
                    0,
                    address(this),
                    withdrawParams[i]
                );
            }
        }
        rebalanceLocalVars.withdrawnAmount =
            rebalanceArgs.depositToken.balanceOf(address(this)) -
            rebalanceLocalVars.withdrawnAmount;

        // depositing into investables that are below the target equity
        rebalanceLocalVars.remainingAmount = rebalanceLocalVars.withdrawnAmount;
        for (uint256 i = 0; i < investableDescsLength; i++) {
            IInvestable embeddedInvestable = investableDescs[i].investable;
            if (currentInvestableEquities[i] < targetInvestableEquities[i]) {
                uint256 depositAmount = Math.min(
                    rebalanceLocalVars.remainingAmount,
                    targetInvestableEquities[i] - currentInvestableEquities[i]
                );

                if (depositAmount != 0) {
                    rebalanceArgs.depositToken.approve(
                        address(embeddedInvestable),
                        depositAmount
                    );
                    embeddedInvestable.deposit(
                        depositAmount,
                        0,
                        address(this),
                        depositParams[i]
                    );
                } else break;
                rebalanceLocalVars.remainingAmount -= depositAmount;
            }
        }

        (
            currentInvestableEquities,
            rebalanceLocalVars.totalEquityAfterRebalance
        ) = getTotalEquity(investableDescs);

        if (
            rebalanceLocalVars.totalEquityAfterRebalance <
            rebalanceArgs.minimumDepositTokenAmountOut
        ) revert IInvestable.TooSmallDepositTokenAmountOut();
    }

    function getTotalEquity(InvestableDesc[] storage investableDescs)
        internal
        view
        returns (
            uint256[] memory currentInvestableEquities,
            uint256 totalEquity
        )
    {
        uint256 investableDescsLength = investableDescs.length;
        currentInvestableEquities = new uint256[](investableDescs.length);
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
    }

    function findInvestableDescInd(
        IInvestable investable,
        InvestableDesc[] storage investableDescs
    ) internal view returns (uint256) {
        for (uint256 i = 0; i < investableDescs.length; ++i)
            if (investableDescs[i].investable == investable) return i;
        return type(uint256).max;
    }

    function deconstructNameValuePairArray(
        NameValuePair[] calldata nameValueParams
    ) internal pure returns (string[] memory keys, bytes[] memory values) {
        uint256 paramsLength = nameValueParams.length;
        keys = new string[](paramsLength);
        values = new bytes[](paramsLength);
        for (uint256 i = 0; i < paramsLength; ++i) {
            keys[i] = nameValueParams[i].key;
            values[i] = nameValueParams[i].value;
        }
    }

    function containsInvestableDesc(
        IInvestable investable,
        InvestableDesc[] storage investableDescs
    ) internal view returns (bool) {
        return
            findInvestableDescInd(investable, investableDescs) !=
            type(uint256).max;
    }

    function addInvestable(
        IInvestable investable,
        uint24[] calldata newAllocations,
        NameValuePair[] calldata params,
        InvestableDesc[] storage investableDescs
    ) external {
        if (containsInvestableDesc(investable, investableDescs))
            revert IPortfolio.InvestableAlreadyAdded();

        // workaround for 'Copying of type struct memory[] memory to storage not yet supported'
        (
            string[] memory keys,
            bytes[] memory values
        ) = deconstructNameValuePairArray(params);

        investableDescs.push(
            InvestableDesc(
                investable,
                newAllocations[newAllocations.length - 1],
                keys,
                values
            )
        );

        setTargetInvestableAllocations(newAllocations, investableDescs);
    }

    function removeInvestable(
        IInvestable investable,
        uint24[] calldata newAllocations,
        InvestableDesc[] storage investableDescs
    ) external {
        uint256 investableDescInd = findInvestableDescInd(
            investable,
            investableDescs
        );
        if (investableDescInd == type(uint256).max)
            revert IPortfolio.InvestableNotYetAdded();
        InvestableDesc storage investableDesc = investableDescs[
            investableDescInd
        ];
        if (investableDesc.allocationPercentage != 0)
            revert IPortfolio.InvestableHasNonZeroAllocation();
        investableDescs[investableDescInd] = investableDescs[
            investableDescs.length - 1
        ];
        investableDescs.pop();
        setTargetInvestableAllocations(newAllocations, investableDescs);
    }

    function changeInvestable(
        IInvestable investable,
        NameValuePair[] calldata params,
        InvestableDesc[] storage investableDescs
    ) external {
        uint256 investableDescInd = findInvestableDescInd(
            investable,
            investableDescs
        );
        if (investableDescInd == type(uint256).max)
            revert IPortfolio.InvestableNotYetAdded();
        InvestableDesc storage investableDesc = investableDescs[
            investableDescInd
        ];
        (
            investableDesc.keys,
            investableDesc.values
        ) = deconstructNameValuePairArray(params);
    }

    function setTargetInvestableAllocations(
        uint24[] calldata newAllocations,
        InvestableDesc[] storage investableDescs
    ) public {
        uint256 totalPercentage;
        uint256 investableDescsLength = investableDescs.length;
        uint256 newAllocationsLength = newAllocations.length;
        for (uint256 i = 0; i < newAllocationsLength; ++i)
            totalPercentage += newAllocations[i];

        if (totalPercentage != uint256(100) * Math.SHORT_FIXED_DECIMAL_FACTOR)
            revert IPortfolio.RebalancePercentageNot100();
        if (investableDescsLength != newAllocationsLength)
            revert IPortfolio.RebalanceIncorrectAllocationsLength();

        for (uint256 i = 0; i < investableDescsLength; i++) {
            investableDescs[i].allocationPercentage = newAllocations[i];
        }
    }
}
