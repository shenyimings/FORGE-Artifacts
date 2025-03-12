// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IDCAInvestable } from "./IDCAInvestable.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IDCAPortfolio is IDCAInvestable {
    error InvestableIsEmergencyExited();
    error InvalidDepositToken();
    error DCAInvestableAlreadyAdded();
    error PortfolioIsEmergencyExited();

    struct Investable {
        IDCAInvestable investable;
        bool emergencyExited;
    }

    struct DCAPortfolioInitArgs {
        IDCAInvestable[] investables;
        IERC20Upgradeable depositToken;
        uint8 investAmountSplit;
    }

    function addDCAInvestable(IDCAInvestable newDCAInvestable) external;
}
