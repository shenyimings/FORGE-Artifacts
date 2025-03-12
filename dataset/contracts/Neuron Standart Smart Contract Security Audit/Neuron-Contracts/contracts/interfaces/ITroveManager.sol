// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

interface ITroveManager {
    event ActivePoolAddressChanged(address _activePoolAddress);
    event BaseRateUpdated(uint256 _baseRate);
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event LQTYStakingAddressChanged(address _lqtyStakingAddress);
    event LQTYTokenAddressChanged(address _lqtyTokenAddress);
    event LTermsUpdated(uint256 _L_ETH, uint256 _L_LUSDDebt);
    event LUSDTokenAddressChanged(address _newLUSDTokenAddress);
    event LastFeeOpTimeUpdated(uint256 _lastFeeOpTime);
    event Liquidation(
        uint256 _liquidatedDebt,
        uint256 _liquidatedColl,
        uint256 _collGasCompensation,
        uint256 _LUSDGasCompensation
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event Redemption(uint256 _attemptedLUSDAmount, uint256 _actualLUSDAmount, uint256 _ETHSent, uint256 _ETHFee);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event SystemSnapshotsUpdated(uint256 _totalStakesSnapshot, uint256 _totalCollateralSnapshot);
    event TotalStakesUpdated(uint256 _newTotalStakes);
    event TroveIndexUpdated(address _borrower, uint256 _newIndex);
    event TroveLiquidated(address indexed _borrower, uint256 _debt, uint256 _coll, uint8 _operation);
    event TroveSnapshotsUpdated(uint256 _L_ETH, uint256 _L_LUSDDebt);
    event TroveUpdated(address indexed _borrower, uint256 _debt, uint256 _coll, uint256 _stake, uint8 _operation);

    function BETA() external view returns (uint256);

    function BOOTSTRAP_PERIOD() external view returns (uint256);

    function BORROWING_FEE_FLOOR() external view returns (uint256);

    function CCR() external view returns (uint256);

    function DECIMAL_PRECISION() external view returns (uint256);

    function LUSD_GAS_COMPENSATION() external view returns (uint256);

    function L_ETH() external view returns (uint256);

    function L_LUSDDebt() external view returns (uint256);

    function MAX_BORROWING_FEE() external view returns (uint256);

    function MCR() external view returns (uint256);

    function MINUTE_DECAY_FACTOR() external view returns (uint256);

    function MIN_NET_DEBT() external view returns (uint256);

    function NAME() external view returns (string memory);

    function PERCENT_DIVISOR() external view returns (uint256);

    function REDEMPTION_FEE_FLOOR() external view returns (uint256);

    function SECONDS_IN_ONE_MINUTE() external view returns (uint256);

    function TroveOwners(uint256) external view returns (address);

    function Troves(address)
        external
        view
        returns (
            uint256 debt,
            uint256 coll,
            uint256 stake,
            uint8 status,
            uint128 arrayIndex
        );

    function _100pct() external view returns (uint256);

    function activePool() external view returns (address);

    function addTroveOwnerToArray(address _borrower) external returns (uint256 index);

    function applyPendingRewards(address _borrower) external;

    function baseRate() external view returns (uint256);

    function batchLiquidateTroves(address[] memory _troveArray) external;

    function borrowerOperationsAddress() external view returns (address);

    function checkRecoveryMode(uint256 _price) external view returns (bool);

    function closeTrove(address _borrower) external;

    function decayBaseRateFromBorrowing() external;

    function decreaseTroveColl(address _borrower, uint256 _collDecrease) external returns (uint256);

    function decreaseTroveDebt(address _borrower, uint256 _debtDecrease) external returns (uint256);

    function defaultPool() external view returns (address);

    function getBorrowingFee(uint256 _LUSDDebt) external view returns (uint256);

    function getBorrowingFeeWithDecay(uint256 _LUSDDebt) external view returns (uint256);

    function getBorrowingRate() external view returns (uint256);

    function getBorrowingRateWithDecay() external view returns (uint256);

    function getCurrentICR(address _borrower, uint256 _price) external view returns (uint256);

    function getEntireDebtAndColl(address _borrower)
        external
        view
        returns (
            uint256 debt,
            uint256 coll,
            uint256 pendingLUSDDebtReward,
            uint256 pendingETHReward
        );

    function getEntireSystemColl() external view returns (uint256 entireSystemColl);

    function getEntireSystemDebt() external view returns (uint256 entireSystemDebt);

    function getNominalICR(address _borrower) external view returns (uint256);

    function getPendingETHReward(address _borrower) external view returns (uint256);

    function getPendingLUSDDebtReward(address _borrower) external view returns (uint256);

    function getRedemptionFeeWithDecay(uint256 _ETHDrawn) external view returns (uint256);

    function getRedemptionRate() external view returns (uint256);

    function getRedemptionRateWithDecay() external view returns (uint256);

    function getTCR(uint256 _price) external view returns (uint256);

    function getTroveColl(address _borrower) external view returns (uint256);

    function getTroveDebt(address _borrower) external view returns (uint256);

    function getTroveFromTroveOwnersArray(uint256 _index) external view returns (address);

    function getTroveOwnersCount() external view returns (uint256);

    function getTroveStake(address _borrower) external view returns (uint256);

    function getTroveStatus(address _borrower) external view returns (uint256);

    function hasPendingRewards(address _borrower) external view returns (bool);

    function increaseTroveColl(address _borrower, uint256 _collIncrease) external returns (uint256);

    function increaseTroveDebt(address _borrower, uint256 _debtIncrease) external returns (uint256);

    function isOwner() external view returns (bool);

    function lastETHError_Redistribution() external view returns (uint256);

    function lastFeeOperationTime() external view returns (uint256);

    function lastLUSDDebtError_Redistribution() external view returns (uint256);

    function liquidate(address _borrower) external;

    function liquidateTroves(uint256 _n) external;

    function lqtyStaking() external view returns (address);

    function lqtyToken() external view returns (address);

    function lusdToken() external view returns (address);

    function owner() external view returns (address);

    function priceFeed() external view returns (address);

    function redeemCollateral(
        uint256 _LUSDamount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external;

    function removeStake(address _borrower) external;

    function rewardSnapshots(address) external view returns (uint256 ETH, uint256 LUSDDebt);

    function setAddresses(
        address _borrowerOperationsAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _lusdTokenAddress,
        address _sortedTrovesAddress,
        address _lqtyTokenAddress,
        address _lqtyStakingAddress
    ) external;

    function setTroveStatus(address _borrower, uint256 _num) external;

    function sortedTroves() external view returns (address);

    function stabilityPool() external view returns (address);

    function totalCollateralSnapshot() external view returns (uint256);

    function totalStakes() external view returns (uint256);

    function totalStakesSnapshot() external view returns (uint256);

    function updateStakeAndTotalStakes(address _borrower) external returns (uint256);

    function updateTroveRewardSnapshots(address _borrower) external;
}
