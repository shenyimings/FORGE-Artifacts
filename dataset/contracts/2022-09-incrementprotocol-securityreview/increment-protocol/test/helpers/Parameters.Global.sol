// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import "../../contracts/interfaces/IClearingHouse.sol";

library Global {
    /* Clearing House params */
    int256 constant minMargin = 0.025 ether;
    int256 constant minMarginAtCreation = 0.055 ether;
    uint256 constant minPositiveOpenNotional = 35 ether;
    uint256 constant liquidationReward = 0.015 ether;
    uint256 constant insuranceRatio = 0.1 ether;
    uint256 constant liquidationRewardInsuranceShare = 0.5 ether;
    uint256 constant liquidationDiscount = 0.95 ether;
    uint256 constant nonUACollSeizureDiscount = 0.75 ether;
    int256 constant uaDebtSeizureThreshold = 10000 ether;

    /* Oracle params */
    uint256 constant gracePeriod = 5 minutes;
    uint24 constant uaHeartBeat = 25 hours;

    /* UA params */
    uint256 constant initialTokenMaxMintCap = 10_000_000 ether;
}
