// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library DCAHistoryLib {
    struct HistoricalGauge {
        uint256 amountSpent;
        uint256 amountExchanged;
    }

    struct DCAHistory {
        HistoricalGauge[] gauges;
        uint256 current;
    }

    function addHistoricalGauge(
        DCAHistory storage history,
        uint256 amountSpent,
        uint256 amountExchanged
    ) internal {
        history.gauges.push(HistoricalGauge(amountSpent, amountExchanged));
        history.current++;
    }

    function increaseHistoricalGaugeAt(
        DCAHistory storage history,
        uint256 rewards,
        uint256 index
    ) internal {
        history.gauges[index].amountExchanged += rewards;
    }

    function decreaseHistoricalGaugeByIndex(
        DCAHistory storage history,
        uint256 index,
        uint256 amountSpent,
        uint256 amountExchanged
    ) internal {
        history.gauges[index].amountSpent -= amountSpent;
        history.gauges[index].amountExchanged -= amountExchanged;
    }

    function currentHistoricalIndex(DCAHistory storage history)
        internal
        view
        returns (uint256)
    {
        return history.current;
    }

    function historicalGaugeByIndex(DCAHistory storage history, uint256 index)
        internal
        view
        returns (uint256, uint256)
    {
        require(index <= history.current, "DCAHistoryLib: Out of bounds");
        return (
            history.gauges[index].amountSpent,
            history.gauges[index].amountExchanged
        );
    }
}
