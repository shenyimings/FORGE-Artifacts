// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./IERDBase.sol";
import "./IStabilityPool.sol";
import "./IActivePool.sol";
import "./IDefaultPool.sol";
import "../DataTypes.sol";

// Common interface for the Trove Manager.
interface ITroveManager is IERDBase {
    // --- Functions ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _eusdTokenAddress,
        address _sortedTrovesAddress,
        address _troveManagerLiquidationsAddress,
        address _troveManagerRedemptionsAddress,
        address _collateralManagerAddress
    ) external;

    // function initTrove(address _troveDebtAddress, address _interestRateAddress)
    //     external;

    function stabilityPool() external view returns (IStabilityPool);

    // function eusdToken() external view returns (IEUSDToken);

    function getCollateralSupport() external view returns (address[] memory);

    function getTroveNormalizedDebt() external view returns (uint256);

    function getTroveOwnersCount() external view returns (uint256);

    function getTroveFromTroveOwnersArray(
        uint256 _index
    ) external view returns (address);

    function getCurrentICR(
        address _borrower,
        uint256 _price
    ) external view returns (uint256);

    function liquidate(address _borrower) external;

    function liquidateTroves(uint256 _n) external;

    function batchLiquidateTroves(address[] calldata _troveArray) external;

    function redeemCollateral(
        uint256 _EUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFee
    ) external;

    function updateStakeAndTotalStakes(address _borrower) external;

    function updateTroveRewardSnapshots(address _borrower) external;

    function addTroveOwnerToArray(
        address _borrower
    ) external returns (uint256 index);

    function applyPendingRewards(address _borrower) external;

    function getPendingCollReward(
        address _borrower
    )
        external
        view
        returns (uint256[] memory, uint256[] memory, address[] memory);

    function getPendingEUSDDebtReward(
        address _borrower
    ) external view returns (uint256);

    function hasPendingRewards(address _borrower) external view returns (bool);

    function getEntireDebtAndColl(
        address _borrower
    )
        external
        view
        returns (
            uint256,
            uint256[] memory,
            uint256,
            uint256[] memory,
            address[] memory
        );

    function closeTrove(address _borrower) external;

    function removeStake(address _borrower) external;

    function getRedemptionRate() external view returns (uint256);

    function getRedemptionRateWithDecay() external view returns (uint256);

    function getRedemptionFeeWithDecay(
        uint256 _collDrawn,
        uint256[] memory _collDrawns
    ) external view returns (uint256, uint256[] memory);

    function getBorrowingRate() external view returns (uint256);

    function getBorrowingRateWithDecay() external view returns (uint256);

    function getBorrowingFee(uint256 EUSDDebt) external view returns (uint256);

    function getBorrowingFeeWithDecay(
        uint256 _EUSDDebt
    ) external view returns (uint256);

    function decayBaseRateFromBorrowing() external;

    function getTroveStatus(address _borrower) external view returns (uint256);

    function getTroveDebt(address _borrower) external view returns (uint256);

    function getTroveColl(
        address _borrower,
        address _collateral
    ) external view returns (uint256, uint256);

    function getTroveColls(
        address _borrower
    )
        external
        view
        returns (uint256[] memory, uint256[] memory, address[] memory);

    function getTroveStake(
        address _borrower,
        address _collateral
    ) external view returns (uint256);

    function getTroveStakes(
        address _borrower
    ) external view returns (uint256[] memory, uint256, address[] memory);

    function getRewardSnapshotColl(
        address _borrower,
        address _collateral
    ) external view returns (uint256);

    function getRewardSnapshotEUSD(
        address _borrower,
        address _collateral
    ) external view returns (uint256);

    function setTroveStatus(address _borrower, uint256 num) external;

    function increaseTroveDebt(
        address _borrower,
        uint256 _debtIncrease
    ) external returns (uint256);

    function decreaseTroveDebt(
        address _borrower,
        uint256 _collDecrease
    ) external returns (uint256);

    function setFactor(uint256 _factor) external;

    function getFactor() external view returns (uint256);

    function getTCR(uint256 _price) external view returns (uint256);

    function checkRecoveryMode(uint256 _price) external view returns (bool);

    function calcDecayedBaseRate() external view returns (uint256);

    function movePendingTroveRewardsToActivePool(
        IActivePool activePool,
        IDefaultPool defaultPool,
        uint256 _EUSD,
        uint256[] memory collAmounts
    ) external;

    function getCurrentTroveAmounts(
        address _borrower
    ) external view returns (uint256[] memory, address[] memory, uint256);

    function redistributeDebtAndColl(
        IActivePool,
        IDefaultPool,
        uint256,
        address[] memory,
        uint256[] memory,
        uint256[] memory
    ) external;

    function updateSystemSnapshots_excludeCollRemainder(
        IActivePool,
        address[] memory,
        uint256[] memory
    ) external;

    function updateBaseRate(uint256 newBaseRate) external;

    function getTotalValue() external view returns (uint256 totalValue);

    function getCCR() external view returns (uint256);

    function getEUSDGasCompensation() external view returns (uint256);

    function getTroveData() external view returns (DataTypes.TroveData memory);
}
