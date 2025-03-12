// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { AppStorage, LibAppStorage } from "src/diamonds/nayms/AppStorage.sol";

struct TradingCommissionsConfig {
    uint16 tradingCommissionTotalBP;
    uint16 tradingCommissionNaymsLtdBP;
    uint16 tradingCommissionNDFBP;
    uint16 tradingCommissionSTMBP;
    uint16 tradingCommissionMakerBP;
}

contract TradingCommissionsFixture {
    function getCommissionsConfig() public returns (TradingCommissionsConfig memory config_) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        config_ = TradingCommissionsConfig({
            tradingCommissionTotalBP: s.tradingCommissionTotalBP,
            tradingCommissionNaymsLtdBP: s.tradingCommissionNaymsLtdBP,
            tradingCommissionNDFBP: s.tradingCommissionNDFBP,
            tradingCommissionSTMBP: s.tradingCommissionSTMBP,
            tradingCommissionMakerBP: s.tradingCommissionMakerBP
        });
    }
}
