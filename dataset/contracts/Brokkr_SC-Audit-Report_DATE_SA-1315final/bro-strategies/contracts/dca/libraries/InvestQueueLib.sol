// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library InvestQueueLib {
    uint256 public constant QUEUE_LEN = 254;

    struct InvestQueue {
        uint256[QUEUE_LEN + 1] investAmounts;
        uint8 current;
    }

    function getCurrentInvestmentAmountAndMoveNext(InvestQueue storage queue)
        internal
        returns (uint256)
    {
        uint256 amount = queue.investAmounts[queue.current];
        queue.investAmounts[queue.current] = 0;
        queue.current = _nextQueueIndex(queue.current);

        return amount;
    }

    function splitUserInvestmentAmount(
        InvestQueue storage queue,
        uint256 amountToInvest,
        uint8 amountSplit
    ) internal {
        // solhint-disable-next-line reason-string
        require(
            amountSplit < queue.investAmounts.length,
            "InvestQueueLib: Invalid amount split"
        );

        uint8 current = queue.current;
        uint256 perPeriodInvestment = amountToInvest / amountSplit;
        for (uint256 i = 0; i < amountSplit; i++) {
            queue.investAmounts[current] += perPeriodInvestment;
            current = _nextQueueIndex(current);
        }
    }

    function removeUserInvestment(
        InvestQueue storage queue,
        uint256 perPeriodInvestment,
        uint8 investmentsToRemove
    ) internal {
        uint8 current = queue.current;
        for (uint256 i = 0; i < investmentsToRemove; i++) {
            queue.investAmounts[current] -= perPeriodInvestment;
            current = _nextQueueIndex(current);
        }
    }

    function _nextQueueIndex(uint8 current) private pure returns (uint8) {
        if (current == QUEUE_LEN) {
            return 0;
        } else {
            return current + 1;
        }
    }
}
