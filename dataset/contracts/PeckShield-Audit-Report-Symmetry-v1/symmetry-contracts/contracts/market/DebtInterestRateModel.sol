// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../utils/SignedSafeDecimalMath.sol";
import "../utils/CommonContext.sol";
import "../utils/Initializable.sol";

import "../interfaces/IMarginTracker.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IMarketSettings.sol";
import "../interfaces/IDebtInterestRateModel.sol";

import "./MarketSettingsContext.sol";

contract DebtInterestRateModel is IDebtInterestRateModel, CommonContext, MarketSettingsContext, Initializable {
    using SignedSafeDecimalMath for int;

    // states
    address public settings;
    address public marginTracker;
    address public market;
    // debtRatio = totalDebt * price / (LP - totalSkew)
    int public debtRatio;
    int public totalDebt;
    // max interest rate and update time
    int public maxInterestRate;
    uint public updatedAt;

    function initialize(address _market, address _marginTracker) external onlyInitializeOnce {
        market = _market;
        settings = IMarket(_market).settings();
        marginTracker = _marginTracker;
    }

    function update(int _totalDebt, int _debtRatio) external {
        require(msg.sender == marginTracker, "DebtInterestRateModel: forbidden");
        totalDebt = _totalDebt;
        debtRatio = _debtRatio;
    }

    function updateMaxInterestRate() external {
        require(msg.sender == marginTracker, "DebtInterestRateModel: forbidden");
        IMarketSettings settings_ = IMarketSettings(settings);
        int vertexDebtRatio = settings_.getIntVals(VERTEX_DEBT_RATIO);
        if (debtRatio <= vertexDebtRatio) {
            maxInterestRate = settings_.getIntVals(MAX_INTEREST_RATE);
        } else {
            maxInterestRate += (int(block.timestamp - updatedAt) * maxInterestRate) / 12 hours;
        }
        updatedAt = block.timestamp;
    }

    function nextInterest() public view returns (int interest) {
        if (updatedAt == block.timestamp || totalDebt == 0) {
            return 0;
        }
        IMarketSettings settings_ = IMarketSettings(settings);
        int vertexDebtRatio = settings_.getIntVals(VERTEX_DEBT_RATIO);
        int vertexIR = settings_.getIntVals(VERTEX_INTEREST_RATE);
        int timeElapsed = int(block.timestamp - updatedAt);
        if (debtRatio <= vertexDebtRatio) {
            int minIR = settings_.getIntVals(MIN_INTEREST_RATE);
            int avgIR = minIR + (debtRatio * (vertexIR - minIR)) / vertexDebtRatio;
            interest = (totalDebt.multiplyDecimal(avgIR) * timeElapsed) / 365 days;
        } else {
            int avgMaxInterestRate = maxInterestRate + (int(block.timestamp - updatedAt) * maxInterestRate) / 24 hours;
            int avgIR = vertexIR +
                ((debtRatio - vertexDebtRatio) * (avgMaxInterestRate - vertexIR)) /
                (_UNIT - vertexDebtRatio);
            interest = (totalDebt.multiplyDecimal(avgIR) * timeElapsed) / 365 days;
        }
    }
}
