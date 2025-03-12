// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./Interfaces/ITroveManager.sol";
import "./Interfaces/ICollateralManager.sol";
import "./Interfaces/IActivePool.sol";
import "./Interfaces/ICollSurplusPool.sol";
import "./Interfaces/IDefaultPool.sol";
import "./Interfaces/IEUSDToken.sol";
import "./Interfaces/ISortedTroves.sol";

library DataTypes {
    enum TroveManagerOperation {
        applyPendingRewards,
        liquidateInNormalMode,
        liquidateInRecoveryMode,
        redeemCollateral
    }

    enum Status {
        nonExistent,
        active,
        closedByOwner,
        closedByLiquidation,
        closedByRedemption
    }

    enum CollStatus {
        nonSupport,
        active,
        pause
    }

    struct CollateralParams {
        uint256 ratio;
        address eToken;
        address oracle;
        CollStatus status;
        uint256 index;
    }

    // Store the necessary data for a trove
    struct Trove {
        mapping(address => uint256) stakes;
        Status status;
        uint128 arrayIndex;
    }

    struct TroveData {
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //borrow index. Expressed in ray
        uint128 borrowIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //the current borrow rate. Expressed in ray
        uint128 currentBorrowRate;
        uint40 lastUpdateTimestamp;
        //troveManager addresses
        address troveManagerAddress;
        //troveDebt addresses
        address troveDebtAddress;
        //address of the interest rate strategy
        address interestRateAddress;
        //address of the EUSD token
        address eusdTokenAddress;
        uint256 factor;
    }

    // Object containing the ETH/wrapperETH and EUSD snapshots for a given active trove
    struct RewardSnapshot {
        mapping(address => uint256) EUSDDebt;
        mapping(address => uint256) collAmounts;
    }

    struct ContractsCache {
        ITroveManager troveManager;
        ICollateralManager collateralManager;
        IActivePool activePool;
        IDefaultPool defaultPool;
        IEUSDToken eusdToken;
        ISortedTroves sortedTroves;
        ICollSurplusPool collSurplusPool;
        address gasPoolAddress;
    }

    // --- Variable container structs for liquidations ---

    struct LiquidationValues {
        uint256 entireTroveDebt;
        uint256[] entireTroveColls;
        uint256[] collGasCompensations;
        uint256 EUSDGasCompensation;
        uint256 debtToOffset;
        uint256[] collToSendToSPs;
        uint256 debtToRedistribute;
        uint256[] collToRedistributes;
        uint256[] collSurpluses;
    }

    struct LiquidationTotals {
        uint256[] totalCollInSequences;
        uint256 totalDebtInSequence;
        uint256[] totalCollGasCompensations;
        uint256 totalEUSDGasCompensation;
        uint256 totalDebtToOffset;
        uint256[] totalCollToSendToSPs;
        uint256 totalDebtToRedistribute;
        uint256[] totalCollToRedistributes;
        uint256[] totalCollSurpluses;
    }

    // --- Variable container structs for redemptions ---

    struct RedemptionTotals {
        uint256 remainingEUSD;
        uint256 totalEUSDToRedeem;
        uint256[] totalCollDrawns;
        uint256 collFee;
        uint256[] collFees;
        uint256[] collToSendToRedeemers;
        uint256 decayedBaseRate;
        uint256 price;
        uint256 totalEUSDSupplyAtStart;
    }

    struct SingleRedemptionValues {
        uint256 EUSDLot;
        address[] collaterals;
        uint256[] collLots;
        uint256[] collRemaind;
        bool cancelledPartial;
    }
}
