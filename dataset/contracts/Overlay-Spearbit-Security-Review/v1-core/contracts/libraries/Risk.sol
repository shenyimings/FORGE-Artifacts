// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library Risk {
    struct Params {
        uint256 k; // funding constant
        uint256 lmbda; // market impact constant
        uint256 delta; // bid-ask static spread constant
        uint256 capPayoff; // payoff cap
        uint256 capNotional; // initial notional cap
        uint256 capLeverage; // initial leverage cap
        uint256 circuitBreakerWindow; // trailing window for circuit breaker
        uint256 circuitBreakerMintTarget; // target worst case inflation rate over trailing window
        uint256 maintenanceMarginFraction; // maintenance margin (mm) constant
        uint256 maintenanceMarginBurnRate; // burn rate for mm constant
        uint256 liquidationFeeRate; // liquidation fee charged on liquidate
        uint256 tradingFeeRate; // trading fee charged on build/unwind
        uint256 minCollateral; // minimum ovl collateral to open position
        uint256 priceDriftUpperLimit; // upper limit for feed price changes since last update
    }
}
