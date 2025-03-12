// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../utils/EnumerableValues.sol";

library VaultMSData {
    // bytes32 public constant opeProtectIdx = keccak256("opeProtectIdx");
    // using EnumerableSet for EnumerableSet.UintSet;
    // using EnumerableValues for EnumerableSet.UintSet;

    uint256 constant COM_RATE_PRECISION = 10**4; //for common rate(leverage, etc.) and hourly rate
    uint256 constant HOUR_RATE_PRECISION = 10**6; //for common rate(leverage, etc.) and hourly rate
    uint256 constant PRC_RATE_PRECISION = 10**10;   //for precise rate  secondly rate
    uint256 constant PRICE_PRECISION = 10**30;
    uint256 constant USDX_DECIMALS = 10 ** 18;

    struct Position {
        address account;
        address collateralToken;
        address indexToken;
        uint256 size;
        uint256 collateral;
        uint256 averagePrice;
        uint256 reserveAmount;
        uint256 lastUpdateTime;
        uint256 aveIncreaseTime;


        uint256 entryFundingRateSec;
        int256 entryPremiumRateSec;

        int256 realisedPnl;

        uint256 stopLossRatio;
        uint256 takeProfitRatio;

        bool isLong;

        int256 accPremiumFee;
        uint256 accFundingFee;
        uint256 accPositionFee;
        uint256 accCollateral;
    }


    struct TokenBase {
        //Setable parts
        bool isFundable;
        bool isStable;
        uint256 weight;  //tokenWeights allows customisation of index composition
        uint256 maxUSDAmounts;  // maxUSDAmounts allows setting a max amount of USDX debt for a token

        //Record only
        uint256 balance;        // tokenBalances is used only to determine _transferIn values
        uint256 poolAmount;     // poolAmounts tracks the number of received tokens that can be used for leverage
                                // this is tracked separately from tokenBalances to exclude funds that are deposited as margin collateral
        uint256 reservedAmount; // reservedAmounts tracks the number of tokens reserved for open leverage positions
    }


    struct TradingFee {
        uint256 fundingRatePerSec; //borrow fee & token util

        uint256 accumulativefundingRateSec;

        int256 longRatePerSec;  //according to position
        int256 shortRatePerSec; //according to position
        int256 accumulativeLongRateSec;
        int256 accumulativeShortRateSec;

        uint256 latestUpdateTime;
        // uint256 lastFundingTimes;     // lastFundingTimes tracks the last time funding was updated for a token
        // uint256 cumulativeFundingRates;// cumulativeFundingRates tracks the funding rates based on utilization
        // uint256 cumulativeLongFundingRates;
        // uint256 cumulativeShortFundingRates;
    }

    struct TradingTax {
        uint256 taxMax;
        uint256 taxDuration;
        uint256 k;
    }

    struct TradingLimit {
        uint256 maxShortSize;
        uint256 maxLongSize;
        uint256 maxTradingSize;

        uint256 maxRatio;
        uint256 countMinSize;
        //Price Impact
    }


    struct TradingRec {
        uint256 shortSize;
        uint256 shortCollateral;
        uint256 shortAveragePrice;
        uint256 longSize;
        uint256 longCollateral;
        uint256 longAveragePrice;
    }

}