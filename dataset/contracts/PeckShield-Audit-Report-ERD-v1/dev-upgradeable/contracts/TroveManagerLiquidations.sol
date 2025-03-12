// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./Interfaces/ITroveManagerLiquidations.sol";
import "./Interfaces/ICollateralManager.sol";
import "./TroveManagerDataTypes.sol";
import "./DataTypes.sol";

contract TroveManagerLiquidations is
    TroveManagerDataTypes,
    ITroveManagerLiquidations
{
    string public constant NAME = "TroveManagerLiquidations";
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    // --- Connected contract declarations ---

    address public borrowerOperationsAddress;

    IStabilityPool public override stabilityPool;

    ITroveManager internal troveManager;

    ICollSurplusPool collSurplusPool;

    // A doubly linked list of Troves, sorted by their sorted by their collateral ratios
    ISortedTroves public sortedTroves;

    // --- Data structures ---

    /*
     * --- Variable container structs for liquidations ---
     *
     * These structs are used to hold, return and assign variables inside the liquidation functions,
     * in order to avoid the error: "CompilerError: Stack too deep".
     **/

    struct LocalVariables_OuterLiquidationFunction {
        uint256 price;
        uint256 EUSDInStabPool;
        bool recoveryModeAtStart;
        uint256 liquidatedDebt;
        uint256[] liquidatedColls;
        address[] collaterals;
    }

    struct LocalVariables_InnerSingleLiquidateFunction {
        uint256[] collToLiquidates;
        uint256 pendingDebtReward;
        uint256[] pendingCollRewards;
        address[] collaterals;
    }

    struct LocalVariables_LiquidationSequence {
        uint256 remainingEUSDInStabPool;
        uint256 i;
        uint256 ICR;
        address user;
        bool backToNormalMode;
        uint256 entireSystemDebt;
        uint256 entireSystemValue;
        uint256[] entireSystemColls;
        address[] collaterals;
    }

    // --- Dependency setter ---
    function initialize() public initializer {
        __Ownable_init();
    }

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
        address _troveManagerAddress,
        address _collateralManagerAddress
    ) external override onlyOwner {
        _requireIsContract(_borrowerOperationsAddress);
        _requireIsContract(_activePoolAddress);
        _requireIsContract(_defaultPoolAddress);
        _requireIsContract(_stabilityPoolAddress);
        _requireIsContract(_gasPoolAddress);
        _requireIsContract(_collSurplusPoolAddress);
        _requireIsContract(_priceFeedAddress);
        _requireIsContract(_eusdTokenAddress);
        _requireIsContract(_sortedTrovesAddress);
        _requireIsContract(_troveManagerAddress);
        _requireIsContract(_collateralManagerAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        activePool = IActivePool(_activePoolAddress);
        defaultPool = IDefaultPool(_defaultPoolAddress);
        stabilityPool = IStabilityPool(_stabilityPoolAddress);
        gasPoolAddress = _gasPoolAddress;
        collSurplusPool = ICollSurplusPool(_collSurplusPoolAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        eusdToken = IEUSDToken(_eusdTokenAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
        troveManager = ITroveManager(_troveManagerAddress);
        collateralManager = ICollateralManager(_collateralManagerAddress);

        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);
        emit GasPoolAddressChanged(_gasPoolAddress);
        emit CollSurplusPoolAddressChanged(_collSurplusPoolAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit EUSDTokenAddressChanged(_eusdTokenAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit CollateralManagerAddressChanged(_collateralManagerAddress);
    }

    function init(
        address _troveDebtAddress
    ) external onlyOwner {
        _requireIsContract(_troveDebtAddress);
        
        troveDebt = ITroveDebt(_troveDebtAddress);
        
        emit TroveDebtAddressChanged(_troveDebtAddress);
    }

    // --- Getters ---

    function getCollateralSupport()
        public
        view
        override
        returns (address[] memory)
    {
        return collateralManager.getCollateralSupport();
    }

    // --- Trove Liquidation functions ---

    // Single liquidation function. Closes the trove if its ICR is lower than the minimum collateral ratio.

    // --- Inner single liquidation functions ---

    // Liquidate one trove, in Normal Mode.
    function _liquidateNormalMode(
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        address _borrower,
        uint256 _EUSDInStabPool,
        uint256 _price
    ) internal returns (DataTypes.LiquidationValues memory singleLiquidation) {
        LocalVariables_InnerSingleLiquidateFunction memory vars;

        (
            singleLiquidation.entireTroveDebt,
            singleLiquidation.entireTroveColls,
            vars.pendingDebtReward,
            vars.pendingCollRewards,
            vars.collaterals
        ) = troveManager.getEntireDebtAndColl(_borrower);

        troveManager.movePendingTroveRewardsToActivePool(
            _activePool,
            _defaultPool,
            vars.pendingDebtReward,
            vars.pendingCollRewards
        );
        troveManager.removeStake(_borrower);

        singleLiquidation.collGasCompensations = _getCollGasCompensation(
            singleLiquidation.entireTroveColls
        );

        singleLiquidation.EUSDGasCompensation = EUSD_GAS_COMPENSATION();

        vars.collToLiquidates = ERDMath._subArray(
            singleLiquidation.entireTroveColls,
            singleLiquidation.collGasCompensations
        );

        (
            singleLiquidation.debtToOffset,
            singleLiquidation.collToSendToSPs,
            singleLiquidation.debtToRedistribute,
            singleLiquidation.collToRedistributes
        ) = _getOffsetAndRedistributionVals(
            _price,
            singleLiquidation.entireTroveDebt,
            vars.collaterals,
            vars.collToLiquidates,
            _EUSDInStabPool
        );

        troveManager.closeTrove(_borrower);
        emit TroveLiquidated(
            _borrower,
            singleLiquidation.entireTroveDebt,
            vars.collaterals,
            singleLiquidation.entireTroveColls,
            DataTypes.TroveManagerOperation.liquidateInNormalMode
        );
        emit TroveUpdated(
            _borrower,
            0,
            new address[](0),
            new uint256[](0),
            DataTypes.TroveManagerOperation.liquidateInNormalMode
        );
        return singleLiquidation;
    }

    // Liquidate one trove, in Recovery Mode.
    function _liquidateRecoveryMode(
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        address _borrower,
        uint256 _ICR,
        uint256 _EUSDInStabPool,
        uint256 _TCR,
        uint256 _price
    ) internal returns (DataTypes.LiquidationValues memory singleLiquidation) {
        LocalVariables_InnerSingleLiquidateFunction memory vars;
        if (troveManager.getTroveOwnersCount() <= 1) {
            return singleLiquidation;
        } // don't liquidate if last trove
        (
            singleLiquidation.entireTroveDebt,
            singleLiquidation.entireTroveColls,
            vars.pendingDebtReward,
            vars.pendingCollRewards,
            vars.collaterals
        ) = troveManager.getEntireDebtAndColl(_borrower);

        singleLiquidation.collGasCompensations = _getCollGasCompensation(
            singleLiquidation.entireTroveColls
        );

        singleLiquidation.EUSDGasCompensation = EUSD_GAS_COMPENSATION();

        vars.collToLiquidates = ERDMath._subArray(
            singleLiquidation.entireTroveColls,
            singleLiquidation.collGasCompensations
        );
        uint256 mcr = MCR();

        // If ICR <= 100%, purely redistribute the Trove across all active Troves
        if (_ICR <= _100pct) {
            troveManager.movePendingTroveRewardsToActivePool(
                _activePool,
                _defaultPool,
                vars.pendingDebtReward,
                vars.pendingCollRewards
            );
            troveManager.removeStake(_borrower);

            singleLiquidation.debtToOffset = 0;

            singleLiquidation.collToSendToSPs = new uint256[](
                vars.collaterals.length
            );

            singleLiquidation.debtToRedistribute = singleLiquidation
                .entireTroveDebt;
            singleLiquidation.collToRedistributes = vars.collToLiquidates;

            troveManager.closeTrove(_borrower);
            emit TroveLiquidated(
                _borrower,
                singleLiquidation.entireTroveDebt,
                vars.collaterals,
                singleLiquidation.entireTroveColls,
                DataTypes.TroveManagerOperation.liquidateInRecoveryMode
            );
            emit TroveUpdated(
                _borrower,
                0,
                new address[](0),
                new uint256[](0),
                DataTypes.TroveManagerOperation.liquidateInRecoveryMode
            );

            // If 100% < ICR < MCR, offset as much as possible, and redistribute the remainder
        } else if ((_ICR > _100pct) && (_ICR < mcr)) {
            troveManager.movePendingTroveRewardsToActivePool(
                _activePool,
                _defaultPool,
                vars.pendingDebtReward,
                vars.pendingCollRewards
            );
            troveManager.removeStake(_borrower);

            (
                singleLiquidation.debtToOffset,
                singleLiquidation.collToSendToSPs,
                singleLiquidation.debtToRedistribute,
                singleLiquidation.collToRedistributes
            ) = _getOffsetAndRedistributionVals(
                _price,
                singleLiquidation.entireTroveDebt,
                vars.collaterals,
                vars.collToLiquidates,
                _EUSDInStabPool
            );

            troveManager.closeTrove(_borrower);
            emit TroveLiquidated(
                _borrower,
                singleLiquidation.entireTroveDebt,
                vars.collaterals,
                singleLiquidation.entireTroveColls,
                DataTypes.TroveManagerOperation.liquidateInRecoveryMode
            );
            emit TroveUpdated(
                _borrower,
                0,
                new address[](0),
                new uint256[](0),
                DataTypes.TroveManagerOperation.liquidateInRecoveryMode
            );
            /*
             * If 110% <= ICR < current TCR (accounting for the preceding liquidations in the current sequence)
             * and there is EUSD in the Stability Pool, only offset, with no redistribution,
             * but at a capped rate of 1.1 and only if the whole debt can be liquidated.
             * The remainder due to the capped rate will be claimable as collateral surplus.
             */
        } else if (
            (_ICR >= mcr) &&
            (_ICR < _TCR) &&
            (singleLiquidation.entireTroveDebt <= _EUSDInStabPool)
        ) {
            troveManager.movePendingTroveRewardsToActivePool(
                _activePool,
                _defaultPool,
                vars.pendingDebtReward,
                vars.pendingCollRewards
            );
            assert(_EUSDInStabPool != 0);

            troveManager.removeStake(_borrower);

            singleLiquidation = _getCappedOffsetVals(
                singleLiquidation.entireTroveDebt,
                vars.collaterals,
                singleLiquidation.entireTroveColls,
                _price,
                mcr
            );

            troveManager.closeTrove(_borrower);
            if (ERDMath._arrayIsNonzero(singleLiquidation.collSurpluses)) {
                collSurplusPool.accountSurplus(
                    _borrower,
                    singleLiquidation.collSurpluses
                );
            }

            emit TroveLiquidated(
                _borrower,
                singleLiquidation.entireTroveDebt,
                vars.collaterals,
                singleLiquidation.collToSendToSPs,
                DataTypes.TroveManagerOperation.liquidateInRecoveryMode
            );
            emit TroveUpdated(
                _borrower,
                0,
                new address[](0),
                new uint256[](0),
                DataTypes.TroveManagerOperation.liquidateInRecoveryMode
            );
        } else {
            // if (_ICR >= MCR && ( _ICR >= _TCR || singleLiquidation.entireTroveDebt > _EUSDInStabPool))
            DataTypes.LiquidationValues memory zeroVals;
            return zeroVals;
        }

        return singleLiquidation;
    }

    /* In a full liquidation, returns the values for a trove's coll and debt to be offset, and coll and debt to be
     * redistributed to active troves.
     */
    function _getOffsetAndRedistributionVals(
        uint256 _price,
        uint256 _debt,
        address[] memory _collaterals,
        uint256[] memory _colls,
        uint256 _EUSDInStabPool
    )
        internal
        view
        returns (
            uint256 debtToOffset,
            uint256[] memory collToSendToSPs,
            uint256 debtToRedistribute,
            uint256[] memory collToRedistributes
        )
    {
        uint256 length = _colls.length;
        collToSendToSPs = new uint256[](length);
        collToRedistributes = new uint256[](length);
        if (_EUSDInStabPool > 0) {
            /*
             * Offset as much debt & collateral as possible against the Stability Pool, and redistribute the remainder
             * between all active troves.
             *
             *  If the trove's debt is larger than the deposited EUSD in the Stability Pool:
             *
             *  - Offset an amount of the trove's debt equal to the EUSD in the Stability Pool
             *  - Send a fraction of the trove's collateral to the Stability Pool, equal to the fraction of its offset debt
             *
             */
            debtToOffset = ERDMath._min(_debt, _EUSDInStabPool);
            (
                uint256 totalLiquidateCollValue,
                uint256[] memory values
            ) = collateralManager.getValue(_collaterals, _colls, _price);
            uint256 totalValueToSendToSP = totalLiquidateCollValue
                .mul(debtToOffset)
                .div(_debt);
            for (uint256 i = length - 1; i >= 0; i--) {
                if (values[i] == 0) {
                    collToSendToSPs[i] = 0;
                    collToRedistributes[i] = 0;
                    if (i == 0) {
                        break;
                    }
                    continue;
                }
                if (totalValueToSendToSP == 0) {
                    collToSendToSPs[i] = 0;
                    collToRedistributes[i] = _colls[i];
                    if (i == 0) {
                        break;
                    }
                    continue;
                }
                if (values[i] < totalValueToSendToSP) {
                    totalValueToSendToSP = totalValueToSendToSP.sub(values[i]);
                    collToSendToSPs[i] = _colls[i];
                    collToRedistributes[i] = 0;
                } else {
                    uint256 offset = _colls[i]
                        .mul(totalValueToSendToSP.mul(_100pct).div(values[i]))
                        .div(_100pct);
                    collToSendToSPs[i] = offset;
                    collToRedistributes[i] = _colls[i].sub(offset);
                    totalValueToSendToSP = 0;
                }
                if (i == 0) {
                    break;
                }
            }
            debtToRedistribute = _debt.sub(debtToOffset);
        } else {
            debtToOffset = 0;
            debtToRedistribute = _debt;
            collToRedistributes = _colls;
        }
    }

    /*
     *  Get its offset coll/debt and ETH gas comp, and close the trove.
     */
    function _getCappedOffsetVals(
        uint256 _entireTroveDebt,
        address[] memory _collaterals,
        uint256[] memory _entireTroveColls,
        uint256 _price,
        uint256 mcr
    )
        internal
        view
        returns (DataTypes.LiquidationValues memory singleLiquidation)
    {
        singleLiquidation.entireTroveDebt = _entireTroveDebt;
        singleLiquidation.entireTroveColls = _entireTroveColls;
        uint256 cappedCollPortionValue = _entireTroveDebt.mul(mcr).div(
            DECIMAL_PRECISION
        ); //.div(_price);

        uint256[] memory cappedCollPortions = _getCappedCollPortion(
            _collaterals,
            _entireTroveColls,
            cappedCollPortionValue,
            _price
        );

        singleLiquidation.collGasCompensations = _getCollGasCompensation(
            cappedCollPortions
        );
        singleLiquidation.EUSDGasCompensation = EUSD_GAS_COMPENSATION();

        singleLiquidation.debtToOffset = _entireTroveDebt;
        singleLiquidation.collToSendToSPs = ERDMath._subArray(
            cappedCollPortions,
            singleLiquidation.collGasCompensations
        );

        singleLiquidation.collSurpluses = ERDMath._subArray(
            _entireTroveColls,
            cappedCollPortions
        );

        singleLiquidation.debtToRedistribute = 0;
        singleLiquidation.collToRedistributes = new uint256[](
            _collaterals.length
        );
    }

    function _getCappedCollPortion(
        address[] memory _collaterals,
        uint256[] memory _colls,
        uint256 _cappedCollPortionValue,
        uint256 _price
    ) internal view returns (uint256[] memory) {
        uint256 portion = _cappedCollPortionValue;
        uint256 collLen = _colls.length;
        uint256[] memory cappedCollPortions = new uint256[](collLen);
        (, uint256[] memory values) = collateralManager.getValue(
            _collaterals,
            _colls,
            _price
        );

        for (uint256 i = collLen - 1; i >= 0; i--) {
            if (values[i] == 0 || portion == 0) {
                cappedCollPortions[i] = 0;
                if (i == 0) {
                    break;
                }
                continue;
            }

            if (values[i] < portion) {
                cappedCollPortions[i] = _colls[i];
                portion = portion.sub(values[i]);
            } else {
                uint256 offset = _colls[i]
                    .mul(portion.mul(_100pct).div(values[i]))
                    .div(_100pct);
                cappedCollPortions[i] = offset;
                portion = 0;
            }
            if (i == 0) {
                break;
            }
        }
        return cappedCollPortions;
    }

    /*
     * Liquidate a sequence of troves. Closes a maximum number of n under-collateralized Troves,
     * starting from the one with the lowest collateral ratio in the system, and moving upwards
     */
    function liquidateTroves(
        uint256 _n,
        address _liquidator
    ) external override {
        _requireCallerisTroveManager();
        DataTypes.ContractsCache memory contractsCache = DataTypes
            .ContractsCache(
                troveManager,
                collateralManager,
                activePool,
                defaultPool,
                IEUSDToken(address(0)),
                sortedTroves,
                ICollSurplusPool(address(0)),
                address(0)
            );
        IStabilityPool stabilityPoolCached = stabilityPool;

        LocalVariables_OuterLiquidationFunction memory vars;
        vars.collaterals = getCollateralSupport();

        DataTypes.LiquidationTotals memory totals;

        vars.price = priceFeed.fetchPrice();
        contractsCache.collateralManager.priceUpdate();
        vars.EUSDInStabPool = stabilityPoolCached.getTotalEUSDDeposits();
        vars.recoveryModeAtStart = _checkRecoveryMode(vars.price);

        // Perform the appropriate liquidation sequence - tally the values, and obtain their totals
        if (vars.recoveryModeAtStart) {
            totals = _getTotalsFromLiquidateTrovesSequence_RecoveryMode(
                contractsCache,
                vars.price,
                vars.EUSDInStabPool,
                _n
            );
        } else {
            // if !vars.recoveryModeAtStart
            totals = _getTotalsFromLiquidateTrovesSequence_NormalMode(
                contractsCache.activePool,
                contractsCache.defaultPool,
                vars.price,
                vars.EUSDInStabPool,
                _n
            );
        }

        require(
            totals.totalDebtInSequence > 0,
            "TroveManagerLiquidations: nothing to liquidate"
        );

        // Move liquidated collateral and EUSD to the appropriate pools
        stabilityPoolCached.offset(
            totals.totalDebtToOffset,
            vars.collaterals,
            totals.totalCollToSendToSPs
        );

        (
            uint256 totalValueToRedistribute,
            uint256[] memory singleValues
        ) = collateralManager.getValue(
                vars.collaterals,
                totals.totalCollToRedistributes
            );

        uint256 singleLen = singleValues.length;
        uint256[] memory proratedDebtForCollaterals = new uint256[](singleLen);
        if (totalValueToRedistribute > 0) {
            for (uint i = 0; i < singleLen; i++) {
                proratedDebtForCollaterals[i] = singleValues[i]
                    .mul(totals.totalDebtToRedistribute)
                    .div(totalValueToRedistribute);
            }
        }
        troveManager.redistributeDebtAndColl(
            contractsCache.activePool,
            contractsCache.defaultPool,
            totals.totalDebtToRedistribute,
            vars.collaterals,
            totals.totalCollToRedistributes,
            proratedDebtForCollaterals
        );

        if (ERDMath._arrayIsNonzero(totals.totalCollSurpluses)) {
            contractsCache.activePool.sendCollateral(
                address(collSurplusPool),
                vars.collaterals,
                totals.totalCollSurpluses
            );
        }

        // Update system snapshots
        troveManager.updateSystemSnapshots_excludeCollRemainder(
            contractsCache.activePool,
            vars.collaterals,
            totals.totalCollGasCompensations
        );

        vars.liquidatedDebt = totals.totalDebtInSequence;
        vars.liquidatedColls = ERDMath._subArray(
            ERDMath._subArray(
                totals.totalCollInSequences,
                totals.totalCollGasCompensations
            ),
            totals.totalCollSurpluses
        );

        emit Liquidation(
            vars.liquidatedDebt,
            vars.liquidatedColls,
            totals.totalCollGasCompensations,
            totals.totalEUSDGasCompensation
        );

        // Send gas compensation to caller
        _sendGasCompensation(
            contractsCache.activePool,
            _liquidator,
            totals.totalEUSDGasCompensation,
            totals.totalCollGasCompensations
        );
    }

    /*
     * This function is used when the liquidateTroves sequence starts during Recovery Mode. However, it
     * handle the case where the system *leaves* Recovery Mode, part way through the liquidation sequence
     */
    function _getTotalsFromLiquidateTrovesSequence_RecoveryMode(
        DataTypes.ContractsCache memory _contractsCache,
        uint256 _price,
        uint256 _EUSDInStabPool,
        uint256 _n
    ) internal returns (DataTypes.LiquidationTotals memory totals) {
        uint256 price = _price;
        LocalVariables_LiquidationSequence memory vars;
        DataTypes.LiquidationValues memory singleLiquidation;

        vars.remainingEUSDInStabPool = _EUSDInStabPool;
        vars.backToNormalMode = false;
        vars.entireSystemDebt = getEntireSystemDebt();
        (vars.collaterals, vars.entireSystemColls) = getEntireSystemColl();

        (vars.entireSystemValue, ) = _contractsCache.collateralManager.getValue(
            vars.collaterals,
            vars.entireSystemColls,
            _price
        );

        vars.user = _contractsCache.sortedTroves.getLast();
        address firstUser = _contractsCache.sortedTroves.getFirst();
        uint256 mcr = MCR();
        for (vars.i = 0; vars.i < _n && vars.user != firstUser; vars.i++) {
            // we need to cache it, because current user is likely going to be deleted
            address nextUser = _contractsCache.sortedTroves.getPrev(vars.user);

            vars.ICR = _getCurrentICR(vars.user, price);

            if (!vars.backToNormalMode) {
                // Break the loop if ICR is greater than MCR and Stability Pool is empty
                if (vars.ICR >= mcr && vars.remainingEUSDInStabPool == 0) {
                    break;
                }

                uint256 TCR = ERDMath._computeCR(
                    vars.entireSystemValue,
                    vars.entireSystemDebt
                );

                singleLiquidation = _liquidateRecoveryMode(
                    _contractsCache.activePool,
                    _contractsCache.defaultPool,
                    vars.user,
                    vars.ICR,
                    vars.remainingEUSDInStabPool,
                    TCR,
                    price
                );

                // Update aggregate trackers
                vars.remainingEUSDInStabPool = vars.remainingEUSDInStabPool.sub(
                    singleLiquidation.debtToOffset
                );
                vars.entireSystemDebt = vars.entireSystemDebt.sub(
                    singleLiquidation.debtToOffset
                );
                uint256[] memory subColls = ERDMath._addArray(
                    ERDMath._addArray(
                        singleLiquidation.collToSendToSPs,
                        singleLiquidation.collGasCompensations
                    ),
                    singleLiquidation.collSurpluses
                );
                vars.entireSystemColls = ERDMath._subArray(
                    vars.entireSystemColls,
                    subColls
                );

                (vars.entireSystemValue, ) = _contractsCache
                    .collateralManager
                    .getValue(vars.collaterals, vars.entireSystemColls, _price);

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(
                    totals,
                    singleLiquidation
                );

                vars.backToNormalMode = !_checkPotentialRecoveryMode(
                    vars.entireSystemValue,
                    vars.entireSystemDebt
                );
            } else if (vars.backToNormalMode && vars.ICR < mcr) {
                singleLiquidation = _liquidateNormalMode(
                    _contractsCache.activePool,
                    _contractsCache.defaultPool,
                    vars.user,
                    vars.remainingEUSDInStabPool,
                    _price
                );

                vars.remainingEUSDInStabPool = vars.remainingEUSDInStabPool.sub(
                    singleLiquidation.debtToOffset
                );

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(
                    totals,
                    singleLiquidation
                );
            } else break; // break if the loop reaches a Trove with ICR >= MCR

            vars.user = nextUser;
        }
    }

    function _getTotalsFromLiquidateTrovesSequence_NormalMode(
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        uint256 _price,
        uint256 _EUSDInStabPool,
        uint256 _n
    ) internal returns (DataTypes.LiquidationTotals memory totals) {
        LocalVariables_LiquidationSequence memory vars;
        DataTypes.LiquidationValues memory singleLiquidation;
        ISortedTroves sortedTrovesCached = sortedTroves;

        vars.remainingEUSDInStabPool = _EUSDInStabPool;
        uint256 mcr = MCR();
        for (vars.i = 0; vars.i < _n; vars.i++) {
            vars.user = sortedTrovesCached.getLast();
            vars.ICR = _getCurrentICR(vars.user, _price);

            if (vars.ICR < mcr) {
                singleLiquidation = _liquidateNormalMode(
                    _activePool,
                    _defaultPool,
                    vars.user,
                    vars.remainingEUSDInStabPool,
                    _price
                );

                vars.remainingEUSDInStabPool = vars.remainingEUSDInStabPool.sub(
                    singleLiquidation.debtToOffset
                );

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(
                    totals,
                    singleLiquidation
                );
            } else break; // break if the loop reaches a Trove with ICR >= MCR
        }
    }

    /*
     * Attempt to liquidate a custom list of troves provided by the caller.
     */
    function batchLiquidateTroves(
        address[] memory _troveArray,
        address _liquidator
    ) public override {
        require(
            _troveArray.length != 0,
            "TroveManagerLiquidations: Calldata address array must not be empty"
        );

        ICollateralManager collateralManagerCached = collateralManager;
        IActivePool activePoolCached = activePool;
        IDefaultPool defaultPoolCached = defaultPool;
        IStabilityPool stabilityPoolCached = stabilityPool;

        LocalVariables_OuterLiquidationFunction memory vars;
        DataTypes.LiquidationTotals memory totals;

        vars.price = priceFeed.fetchPrice();
        collateralManagerCached.priceUpdate();
        vars.EUSDInStabPool = stabilityPoolCached.getTotalEUSDDeposits();
        vars.recoveryModeAtStart = _checkRecoveryMode(vars.price);

        // Perform the appropriate liquidation sequence - tally values and obtain their totals.
        if (vars.recoveryModeAtStart) {
            totals = _getTotalFromBatchLiquidate_RecoveryMode(
                collateralManagerCached,
                activePoolCached,
                defaultPoolCached,
                vars.price,
                vars.EUSDInStabPool,
                _troveArray
            );
        } else {
            //  if !vars.recoveryModeAtStart
            totals = _getTotalsFromBatchLiquidate_NormalMode(
                activePoolCached,
                defaultPoolCached,
                vars.price,
                vars.EUSDInStabPool,
                _troveArray
            );
        }

        require(
            totals.totalDebtInSequence > 0,
            "TroveManagerLiquidations: nothing to liquidate"
        );

        vars.collaterals = collateralManagerCached.getCollateralSupport();
        // Move liquidated collateral and EUSD to the appropriate pools
        stabilityPoolCached.offset(
            totals.totalDebtToOffset,
            vars.collaterals,
            totals.totalCollToSendToSPs
        );

        (
            uint256 totalValueToRedistribute,
            uint256[] memory singleValues
        ) = collateralManager.getValue(
                vars.collaterals,
                totals.totalCollToRedistributes
            );

        uint256 singleLen = singleValues.length;
        uint256[] memory proratedDebtForCollaterals = new uint256[](singleLen);
        if (totalValueToRedistribute > 0) {
            for (uint i = 0; i < singleLen; i++) {
                proratedDebtForCollaterals[i] = singleValues[i]
                    .mul(totals.totalDebtToRedistribute)
                    .div(totalValueToRedistribute);
            }
        }

        troveManager.redistributeDebtAndColl(
            activePoolCached,
            defaultPoolCached,
            totals.totalDebtToRedistribute,
            vars.collaterals,
            totals.totalCollToRedistributes,
            proratedDebtForCollaterals
        );

        if (ERDMath._arrayIsNonzero(totals.totalCollSurpluses)) {
            activePoolCached.sendCollateral(
                address(collSurplusPool),
                getCollateralSupport(),
                totals.totalCollSurpluses
            );
        }

        // Update system snapshots
        troveManager.updateSystemSnapshots_excludeCollRemainder(
            activePoolCached,
            vars.collaterals,
            totals.totalCollGasCompensations
        );

        vars.liquidatedDebt = totals.totalDebtInSequence;
        uint256[] memory tmpColls = ERDMath._subArray(
            totals.totalCollInSequences,
            totals.totalCollGasCompensations
        );
        vars.liquidatedColls = ERDMath._subArray(
            tmpColls,
            totals.totalCollSurpluses
        );
        emit Liquidation(
            vars.liquidatedDebt,
            vars.liquidatedColls,
            totals.totalCollGasCompensations,
            totals.totalEUSDGasCompensation
        );

        // Send gas compensation to caller
        _sendGasCompensation(
            activePoolCached,
            _liquidator,
            totals.totalEUSDGasCompensation,
            totals.totalCollGasCompensations
        );
    }

    /*
     * This function is used when the batch liquidation sequence starts during Recovery Mode. However, it
     * handle the case where the system *leaves* Recovery Mode, part way through the liquidation sequence
     */
    function _getTotalFromBatchLiquidate_RecoveryMode(
        ICollateralManager _collateralManager,
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        uint256 _price,
        uint256 _EUSDInStabPool,
        address[] memory _troveArray
    ) internal returns (DataTypes.LiquidationTotals memory totals) {
        LocalVariables_LiquidationSequence memory vars;
        DataTypes.LiquidationValues memory singleLiquidation;

        vars.remainingEUSDInStabPool = _EUSDInStabPool;
        vars.backToNormalMode = false;
        vars.entireSystemDebt = getEntireSystemDebt();
        (vars.collaterals, vars.entireSystemColls) = getEntireSystemColl();

        (vars.entireSystemValue, ) = _collateralManager.getValue(
            vars.collaterals,
            vars.entireSystemColls,
            _price
        );

        uint256 mcr = MCR();
        for (vars.i = 0; vars.i < _troveArray.length; vars.i++) {
            vars.user = _troveArray[vars.i];
            // Skip non-active troves
            if (troveManager.getTroveStatus(vars.user) != 1) {
                continue;
            }
            vars.ICR = _getCurrentICR(vars.user, _price);

            if (!vars.backToNormalMode) {
                // Skip this trove if ICR is greater than MCR and Stability Pool is empty
                if (vars.ICR >= mcr && vars.remainingEUSDInStabPool == 0) {
                    continue;
                }

                uint256 TCR = ERDMath._computeCR(
                    vars.entireSystemValue,
                    vars.entireSystemDebt
                );

                singleLiquidation = _liquidateRecoveryMode(
                    _activePool,
                    _defaultPool,
                    vars.user,
                    vars.ICR,
                    vars.remainingEUSDInStabPool,
                    TCR,
                    _price
                );

                // Update aggregate trackers
                vars.remainingEUSDInStabPool = vars.remainingEUSDInStabPool.sub(
                    singleLiquidation.debtToOffset
                );
                vars.entireSystemDebt = vars.entireSystemDebt.sub(
                    singleLiquidation.debtToOffset
                );
                uint256[] memory subColls = ERDMath._addArray(
                    ERDMath._addArray(
                        singleLiquidation.collToSendToSPs,
                        singleLiquidation.collGasCompensations
                    ),
                    singleLiquidation.collSurpluses
                );
                vars.entireSystemColls = ERDMath._subArray(
                    vars.entireSystemColls,
                    subColls
                );

                (vars.entireSystemValue, ) = _collateralManager.getValue(
                    vars.collaterals,
                    vars.entireSystemColls,
                    _price
                );

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(
                    totals,
                    singleLiquidation
                );

                vars.backToNormalMode = !_checkPotentialRecoveryMode(
                    vars.entireSystemValue,
                    vars.entireSystemDebt
                );
            } else if (vars.backToNormalMode && vars.ICR < mcr) {
                singleLiquidation = _liquidateNormalMode(
                    _activePool,
                    _defaultPool,
                    vars.user,
                    vars.remainingEUSDInStabPool,
                    _price
                );
                vars.remainingEUSDInStabPool = vars.remainingEUSDInStabPool.sub(
                    singleLiquidation.debtToOffset
                );

                // Add liquidation values to their respective running totals
                totals = _addLiquidationValuesToTotals(
                    totals,
                    singleLiquidation
                );
            } else continue; // In Normal Mode skip troves with ICR >= MCR
        }
    }

    function _getTotalsFromBatchLiquidate_NormalMode(
        IActivePool _activePool,
        IDefaultPool _defaultPool,
        uint256 _price,
        uint256 _EUSDInStabPool,
        address[] memory _troveArray
    ) internal returns (DataTypes.LiquidationTotals memory totals) {
        LocalVariables_LiquidationSequence memory vars;
        DataTypes.LiquidationValues memory singleLiquidation;

        vars.remainingEUSDInStabPool = _EUSDInStabPool;

        uint256 mcr = MCR();
        for (vars.i = 0; vars.i < _troveArray.length; vars.i++) {
            vars.user = _troveArray[vars.i];
            vars.ICR = _getCurrentICR(vars.user, _price);

            if (vars.ICR < mcr) {
                singleLiquidation = _liquidateNormalMode(
                    _activePool,
                    _defaultPool,
                    vars.user,
                    vars.remainingEUSDInStabPool,
                    _price
                );

                vars.remainingEUSDInStabPool = vars.remainingEUSDInStabPool.sub(
                    singleLiquidation.debtToOffset
                );

                totals = _addLiquidationValuesToTotals(
                    totals,
                    singleLiquidation
                );
            }
        }
    }

    // --- Liquidation helper functions ---

    function _addLiquidationValuesToTotals(
        DataTypes.LiquidationTotals memory oldTotals,
        DataTypes.LiquidationValues memory singleLiquidation
    ) internal pure returns (DataTypes.LiquidationTotals memory newTotals) {
        // Tally all the values with their respective running totals
        newTotals.totalCollGasCompensations = ERDMath._addArray(
            oldTotals.totalCollGasCompensations,
            singleLiquidation.collGasCompensations
        );

        newTotals.totalEUSDGasCompensation = oldTotals
            .totalEUSDGasCompensation
            .add(singleLiquidation.EUSDGasCompensation);

        newTotals.totalDebtInSequence = oldTotals.totalDebtInSequence.add(
            singleLiquidation.entireTroveDebt
        );

        newTotals.totalCollInSequences = ERDMath._addArray(
            oldTotals.totalCollInSequences,
            singleLiquidation.entireTroveColls
        );

        newTotals.totalDebtToOffset = oldTotals.totalDebtToOffset.add(
            singleLiquidation.debtToOffset
        );

        newTotals.totalCollToSendToSPs = ERDMath._addArray(
            oldTotals.totalCollToSendToSPs,
            singleLiquidation.collToSendToSPs
        );

        newTotals.totalDebtToRedistribute = oldTotals
            .totalDebtToRedistribute
            .add(singleLiquidation.debtToRedistribute);
        newTotals.totalCollToRedistributes = ERDMath._addArray(
            oldTotals.totalCollToRedistributes,
            singleLiquidation.collToRedistributes
        );

        newTotals.totalCollSurpluses = ERDMath._addArray(
            oldTotals.totalCollSurpluses,
            singleLiquidation.collSurpluses
        );

        return newTotals;
    }

    function _sendGasCompensation(
        IActivePool _activePool,
        address _liquidator,
        uint256 _EUSD,
        uint256[] memory _collAmounts
    ) internal {
        if (_EUSD > 0) {
            eusdToken.returnFromPool(gasPoolAddress, _liquidator, _EUSD);
        }

        _activePool.sendCollateral(
            _liquidator,
            getCollateralSupport(),
            _collAmounts
        );
    }

    // --- Helper functions ---

    // Return the current collateral ratio (ICR) of a given Trove. Takes a trove's pending coll and debt rewards from redistributions into account.
    function _getCurrentICR(
        address _borrower,
        uint256 _price
    ) internal view returns (uint256) {
        return troveManager.getCurrentICR(_borrower, _price);
    }

    // --- Recovery Mode and TCR functions ---

    // Check whether or not the system *would be* in Recovery Mode, given an ETH:USD price, and the entire system coll and debt.
    function _checkPotentialRecoveryMode(
        uint256 _entireSystemCollValue,
        uint256 _entireSystemDebt
    ) internal view returns (bool) {
        uint256 TCR = ERDMath._computeCR(
            _entireSystemCollValue,
            _entireSystemDebt
        );

        return TCR < collateralManager.getCCR();
    }

    function MCR() internal view returns (uint256) {
        return collateralManager.getMCR();
    }

    function EUSD_GAS_COMPENSATION() internal view returns (uint256) {
        return collateralManager.getEUSDGasCompensation();
    }

    function _checkRecoveryMode(uint256 _price) internal view returns (bool) {
        return troveManager.checkRecoveryMode(_price);
    }

    // --- 'require' wrapper functions ---

    function _requireIsContract(address _contract) internal view {
        require(_contract.isContract(), "TroveManager: Contract check error");
    }

    function _requireCallerisTroveManager() internal view {
        require(
            msg.sender == address(troveManager),
            "TroveManagerLiquidations: Caller not TM"
        );
    }
}
