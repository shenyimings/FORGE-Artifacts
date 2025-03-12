// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import { INayms, IDiamondCut } from "src/diamonds/nayms/INayms.sol";
import { PolicyCommissionsBasisPoints, TradingCommissionsBasisPoints } from "src/diamonds/nayms/interfaces/FreeStructs.sol";

contract UpdateCommissions is Script {
    function tradingAndPremium(address naymsDiamondAddress) public {
        vm.startBroadcast();
        trading(naymsDiamondAddress);
        premiums(naymsDiamondAddress);
        vm.stopBroadcast();
    }

    function trading(address naymsDiamondAddress) public {
        INayms nayms = INayms(naymsDiamondAddress);

        TradingCommissionsBasisPoints memory tc = TradingCommissionsBasisPoints({
            tradingCommissionTotalBP: 40,
            tradingCommissionNaymsLtdBP: 5000,
            tradingCommissionNDFBP: 2500,
            tradingCommissionSTMBP: 2500,
            tradingCommissionMakerBP: 0
        });

        nayms.setTradingCommissionsBasisPoints(tc);

        console2.log("\n\nTrading commissions updated successfully");
        console2.log(" - tradingCommissionTotalBP: ", tc.tradingCommissionTotalBP);
        console2.log(" - tradingCommissionNaymsLtdBP: ", tc.tradingCommissionNaymsLtdBP);
        console2.log(" - tradingCommissionNDFBP", tc.tradingCommissionNDFBP);
        console2.log(" - tradingCommissionSTMBP", tc.tradingCommissionSTMBP);
        console2.log(" - tradingCommissionMakerBP: ", tc.tradingCommissionMakerBP);
    }

    function premiums(address naymsDiamondAddress) public {
        INayms nayms = INayms(naymsDiamondAddress);

        // prettier-ignore
        PolicyCommissionsBasisPoints memory pc = PolicyCommissionsBasisPoints({
          premiumCommissionNaymsLtdBP: 40,
          premiumCommissionNDFBP: 40,
          premiumCommissionSTMBP: 40
        });

        nayms.setPolicyCommissionsBasisPoints(pc);

        console2.log("\n\nPremium commissions updated successfully");
        console2.log(" - premiumCommissionNaymsLtdBP: ", pc.premiumCommissionNaymsLtdBP);
        console2.log(" - premiumCommissionNDFBP: ", pc.premiumCommissionNDFBP);
        console2.log(" - premiumCommissionSTMBP: ", pc.premiumCommissionSTMBP);
    }
}
