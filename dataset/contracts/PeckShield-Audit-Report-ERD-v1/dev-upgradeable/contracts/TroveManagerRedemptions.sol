// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./Interfaces/ITroveManagerRedemptions.sol";
import "./TroveManagerDataTypes.sol";
import "./DataTypes.sol";

contract TroveManagerRedemptions is
    TroveManagerDataTypes,
    ITroveManagerRedemptions
{
    string public constant NAME = "TroveManagerRedemptions";
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
     * BETA: 18 digit decimal. Parameter by which to divide the redeemed fraction, in order to calc the new base rate from a redemption.
     * Corresponds to (1 / ALPHA) in the white paper.
     */
    uint256 public constant BETA = 2;

    uint256 internal deploymentStartTime;

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

        deploymentStartTime = block.timestamp;

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

    function init(address _troveDebtAddress) external onlyOwner {
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
        return troveManager.getCollateralSupport();
    }

    // --- Redemption functions ---

    // Redeem as much collateral as possible from _borrower's Trove in exchange for EUSD up to _maxEUSDamount
    function _redeemCollateralFromTrove(
        DataTypes.ContractsCache memory _contractsCache,
        address _borrower,
        uint256 _maxEUSDamount,
        uint256 _price,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintICR
    )
        internal
        returns (DataTypes.SingleRedemptionValues memory singleRedemption)
    {
        DataTypes.ContractsCache memory contractsCache = _contractsCache;
        uint256 price = _price;
        address borrower = _borrower;
        address upperPartialRedemptionHint = _upperPartialRedemptionHint;
        address lowerPartialRedemptionHint = _lowerPartialRedemptionHint;
        uint256 partialRedemptionHintICR = _partialRedemptionHintICR;
        uint256 debt;
        (uint256[] memory colls, address[] memory collAssets, ) = contractsCache
            .troveManager
            .getCurrentTroveAmounts(borrower);
        singleRedemption.collaterals = collAssets;
        {
            debt = contractsCache.troveManager.getTroveDebt(borrower);
            // Determine the remaining amount (lot) to be redeemed, capped by the entire debt of the Trove minus the liquidation reserve

            singleRedemption.EUSDLot = ERDMath._min(
                _maxEUSDamount,
                debt.sub(EUSD_GAS_COMPENSATION())
            );

            // Get the collLot of equivalent value in USD
            (
                singleRedemption.collLots,
                singleRedemption.collRemaind
            ) = _calculateCollLot(
                singleRedemption.EUSDLot,
                collAssets,
                colls,
                price
            );
        }
        uint256[] memory collRemainds = singleRedemption.collRemaind;

        // Decrease the debt and collateral of the current Trove according to the EUSD lot and corresponding collateral to send
        uint256 newDebt = debt.sub(singleRedemption.EUSDLot);
        (uint256 newValue, ) = contractsCache.collateralManager.getValue(
            collAssets,
            collRemainds,
            price
        );

        uint256 gas = EUSD_GAS_COMPENSATION();
        if (newDebt == gas) {
            // No debt left in the Trove (except for the liquidation reserve), therefore the trove gets closed
            troveManager.removeStake(borrower);
            troveManager.closeTrove(borrower);

            _redeemCloseTrove(contractsCache, borrower, gas, collRemainds);
            emit TroveUpdated(
                borrower,
                0,
                new address[](0),
                new uint256[](0),
                DataTypes.TroveManagerOperation.redeemCollateral
            );
        } else {
            uint256 newICR = ERDMath._computeCR(newValue, newDebt);

            /*
             * If the provided hint is out of date, we bail since trying to reinsert without a good hint will almost
             * certainly result in running out of gas.
             *
             * If the resultant net debt of the partial is less than the minimum, net debt we bail.
             */
            if (
                newICR >= partialRedemptionHintICR.add(1e17) ||
                newICR <= partialRedemptionHintICR.sub(1e17) ||
                _getNetDebt(newDebt, gas) <
                contractsCache.collateralManager.getMinNetDebt()
            ) {
                singleRedemption.cancelledPartial = true;
                return singleRedemption;
            }

            contractsCache.sortedTroves.reInsert(
                borrower,
                newICR,
                upperPartialRedemptionHint,
                lowerPartialRedemptionHint
            );
            uint256 EUSDLot = singleRedemption.EUSDLot;
            contractsCache.troveManager.decreaseTroveDebt(borrower, EUSDLot);
            uint256[] memory shares = contractsCache
                .collateralManager
                .resetEToken(borrower, collAssets, collRemainds);
            contractsCache.troveManager.updateStakeAndTotalStakes(borrower);

            emit TroveUpdated(
                borrower,
                newDebt,
                collAssets,
                shares,
                DataTypes.TroveManagerOperation.redeemCollateral
            );
        }

        return singleRedemption;
    }

    function _calculateCollLot(
        uint256 _EUSDLot,
        address[] memory _collaterals,
        uint256[] memory _colls,
        uint256 _price
    ) internal view returns (uint256[] memory, uint256[] memory) {
        uint256 EUSDLot = _EUSDLot;
        uint256 collLen = _colls.length;
        uint256[] memory colls = new uint256[](collLen);
        uint256[] memory remaindColls = new uint256[](collLen);
        (uint256 totalValue, uint256[] memory values) = collateralManager
            .getValue(_collaterals, _colls, _price);
        bool flag = totalValue < EUSDLot;
        if (flag) {
            for (uint256 i = collLen - 1; i >= 0; i--) {
                colls[i] = _colls[i];
                remaindColls[i] = 0;
                if (i == 0) {
                    break;
                }
            }
        } else {
            for (uint256 i = collLen - 1; i >= 0; i--) {
                uint256 value = values[i];
                uint256 coll = _colls[i];
                if (value != 0) {
                    if (EUSDLot == 0) {
                        remaindColls[i] = coll;
                        if (i == 0) {
                            break;
                        }
                        continue;
                    }
                    if (value < EUSDLot) {
                        colls[i] = coll;
                        EUSDLot = EUSDLot.sub(value);
                        // trove.colls[collateral] = 0;
                        remaindColls[i] = 0;
                    } else {
                        uint256 portion = EUSDLot.mul(_100pct).div(value);
                        uint256 offset = coll.mul(portion).div(_100pct);
                        colls[i] = offset;
                        remaindColls[i] = coll.sub(offset);
                        EUSDLot = 0;
                    }
                    if (i == 0) {
                        break;
                    }
                }
            }
        }
        return (colls, remaindColls);
    }

    /*
     * Called when a full redemption occurs, and closes the trove.
     * The redeemer swaps (debt - liquidation reserve) EUSD for (debt - liquidation reserve) worth of ETH, so the EUSD liquidation reserve left corresponds to the remaining debt.
     * In order to close the trove, the EUSD liquidation reserve is burned, and the corresponding debt is removed from the active pool.
     * The debt recorded on the trove's struct is zero'd elswhere, in _closeTrove.
     * Any surplus collateral left in the trove, is sent to the Coll surplus pool, and can be later claimed by the borrower.
     */
    function _redeemCloseTrove(
        DataTypes.ContractsCache memory _contractsCache,
        address _borrower,
        uint256 _EUSD,
        uint256[] memory _collAmounts
    ) internal {
        _contractsCache.eusdToken.burn(gasPoolAddress, _EUSD);
        // Update Active Pool EUSD, and send collateral to account
        _contractsCache.activePool.decreaseEUSDDebt(_EUSD);
        // send collateral from Active Pool to CollSurplus Pool
        _contractsCache.collSurplusPool.accountSurplus(_borrower, _collAmounts);
        _contractsCache.activePool.sendCollateral(
            address(_contractsCache.collSurplusPool),
            getCollateralSupport(),
            _collAmounts
        );
    }

    function _isValidFirstRedemptionHint(
        ISortedTroves _sortedTroves,
        address _firstRedemptionHint,
        uint256 _price
    ) internal view returns (bool) {
        uint256 mcr = MCR();
        if (
            _firstRedemptionHint == address(0) ||
            !_sortedTroves.contains(_firstRedemptionHint) ||
            _getCurrentICR(_firstRedemptionHint, _price) < mcr
        ) {
            return false;
        }

        address nextTrove = _sortedTroves.getNext(_firstRedemptionHint);
        return
            nextTrove == address(0) || _getCurrentICR(nextTrove, _price) < mcr;
    }

    /* Send _EUSDamount EUSD to the system and redeem the corresponding amount of collateral from as many Troves as are needed to fill the redemption
     * request.  Applies pending rewards to a Trove before reducing its debt and coll.
     *
     * Note that if _amount is very large, this function can run out of gas, specially if traversed troves are small. This can be easily avoided by
     * splitting the total _amount in appropriate chunks and calling the function multiple times.
     *
     * Param `_maxIterations` can also be provided, so the loop through Troves is capped (if it’s zero, it will be ignored).This makes it easier to
     * avoid OOG for the frontend, as only knowing approximately the average cost of an iteration is enough, without needing to know the “topology”
     * of the trove list. It also avoids the need to set the cap in stone in the contract, nor doing gas calculations, as both gas price and opcode
     * costs can vary.
     *
     * All Troves that are redeemed from -- with the likely exception of the last one -- will end up with no debt left, therefore they will be closed.
     * If the last Trove does have some remaining debt, it has a finite ICR, and the reinsertion could be anywhere in the list, therefore it requires a hint.
     * A frontend should use getRedemptionHints() to calculate what the ICR of this Trove will be after redemption, and pass a hint for its position
     * in the sortedTroves list along with the ICR value that the hint was found for.
     *
     * If another transaction modifies the list between calling getRedemptionHints() and passing the hints to redeemCollateral(), it
     * is very likely that the last (partially) redeemed Trove would end up with a different ICR than what the hint is for. In this case the
     * redemption will stop after the last completely redeemed Trove and the sender will keep the remaining EUSD amount, which they can attempt
     * to redeem later.
     */
    function redeemCollateral(
        uint256 _EUSDamount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage,
        address _redeemer
    ) external override {
        _requireCallerisTroveManager();
        DataTypes.ContractsCache memory contractsCache = DataTypes
            .ContractsCache(
                troveManager,
                collateralManager,
                activePool,
                defaultPool,
                eusdToken,
                sortedTroves,
                collSurplusPool,
                gasPoolAddress
            );
        DataTypes.RedemptionTotals memory totals;
        address upperPartialRedemptionHint = _upperPartialRedemptionHint;
        address lowerPartialRedemptionHint = _lowerPartialRedemptionHint;
        uint256 partialRedemptionHintICR = _partialRedemptionHintICR;
        uint256 EUSDamount = _EUSDamount;

        _requireValidMaxFeePercentage(_maxFeePercentage);
        _requireAfterBootstrapPeriod();
        totals.price = priceFeed.fetchPrice();
        contractsCache.collateralManager.priceUpdate();
        _requireTCRoverMCR(totals.price);
        _requireAmountGreaterThanZero(EUSDamount);
        _requireEUSDBalanceCoversRedemption(
            contractsCache.eusdToken,
            _redeemer,
            EUSDamount
        );

        totals.totalEUSDSupplyAtStart = getEntireSystemDebt();
        // Confirm redeemer's balance is less than total EUSD supply
        assert(
            contractsCache.eusdToken.balanceOf(_redeemer) <=
                totals.totalEUSDSupplyAtStart
        );

        totals.remainingEUSD = EUSDamount;
        address currentBorrower;

        if (
            _isValidFirstRedemptionHint(
                contractsCache.sortedTroves,
                _firstRedemptionHint,
                totals.price
            )
        ) {
            currentBorrower = _firstRedemptionHint;
        } else {
            currentBorrower = contractsCache.sortedTroves.getLast();
            uint256 mcr = MCR();
            // Find the first trove with ICR >= MCR
            while (
                currentBorrower != address(0) &&
                _getCurrentICR(currentBorrower, totals.price) < mcr
            ) {
                currentBorrower = contractsCache.sortedTroves.getPrev(
                    currentBorrower
                );
            }
        }
        // Loop through the Troves starting from the one with lowest collateral ratio until _amount of EUSD is exchanged for collateral
        if (_maxIterations == 0) {
            // _maxIterations = uint256(-1);
            _maxIterations = type(uint256).max;
        }
        address[] memory collaterals = getCollateralSupport();
        while (
            currentBorrower != address(0) &&
            totals.remainingEUSD > 0 &&
            _maxIterations > 0
        ) {
            _maxIterations--;
            // Save the address of the Trove preceding the current one, before potentially modifying the list
            address nextUserToCheck = contractsCache.sortedTroves.getPrev(
                currentBorrower
            );

            troveManager.applyPendingRewards(currentBorrower);

            DataTypes.SingleRedemptionValues
                memory singleRedemption = _redeemCollateralFromTrove(
                    contractsCache,
                    currentBorrower,
                    totals.remainingEUSD,
                    totals.price,
                    upperPartialRedemptionHint,
                    lowerPartialRedemptionHint,
                    partialRedemptionHintICR
                );

            if (singleRedemption.cancelledPartial) break; // Partial redemption was cancelled (out-of-date hint, or new net debt < minimum), therefore we could not redeem from the last Trove

            totals.totalEUSDToRedeem = totals.totalEUSDToRedeem.add(
                singleRedemption.EUSDLot
            );
            totals.totalCollDrawns = ERDMath._addArray(
                totals.totalCollDrawns,
                singleRedemption.collLots
            );

            totals.remainingEUSD = totals.remainingEUSD.sub(
                singleRedemption.EUSDLot
            );
            currentBorrower = nextUserToCheck;
        }
        require(
            ERDMath._arrayIsNonzero(totals.totalCollDrawns),
            "TroveManagerRedemtions: Unable to redeem any amount"
        );

        (uint256 totalCollDrawnValue, ) = contractsCache
            .collateralManager
            .getValue(collaterals, totals.totalCollDrawns, totals.price);

        // Decay the baseRate due to time passed, and then increase it according to the size of this redemption.
        // Use the saved total EUSD supply value, from before it was reduced by the redemption.
        _updateBaseRateFromRedemption(
            totalCollDrawnValue,
            totals.totalEUSDSupplyAtStart
        );

        // Calculate the collateral fee
        (totals.collFee, totals.collFees) = _getRedemptionFee(
            totalCollDrawnValue,
            totals.totalCollDrawns
        );

        _requireUserAcceptsFee(
            totals.collFee,
            totalCollDrawnValue,
            _maxFeePercentage
        );

        // Send the collateral fee to the treasury/liquidityIncentive contract
        contractsCache.activePool.sendCollFees(
            getCollateralSupport(),
            totals.collFees
        );

        // totals.collToSendToRedeemer = totals.totalCollDrawn.sub(totals.collFee);

        totals.collToSendToRedeemers = ERDMath._subArray(
            totals.totalCollDrawns,
            totals.collFees
        );

        emit Redemption(
            EUSDamount,
            totals.totalEUSDToRedeem,
            collaterals,
            totals.totalCollDrawns,
            totals.collFees
        );

        // Burn the total EUSD that is cancelled with debt, and send the redeemed collateral to msg.sender
        contractsCache.eusdToken.burn(_redeemer, totals.totalEUSDToRedeem);
        // Update Active Pool EUSD, and send collateral to account
        contractsCache.activePool.decreaseEUSDDebt(totals.totalEUSDToRedeem);
        contractsCache.activePool.sendCollateral(
            _redeemer,
            getCollateralSupport(),
            totals.collToSendToRedeemers
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

    // --- Redemption fee functions ---

    /*
     * This function has two impacts on the baseRate state variable:
     * 1) decays the baseRate based on time passed since last redemption or EUSD borrowing operation.
     * then,
     * 2) increases the baseRate based on the amount redeemed, as a proportion of total supply
     */
    function _updateBaseRateFromRedemption(
        uint256 _collDrawnValue,
        uint256 _totalEUSDSupply
    ) internal returns (uint256) {
        uint256 decayedBaseRate = troveManager.calcDecayedBaseRate();
        /* Convert the drawn collateral back to EUSD at face value rate (1 EUSD:1 USD), in order to get
         * the fraction of total supply that was redeemed at face value. */
        uint256 redeemedEUSDFraction = _collDrawnValue
            .mul(DECIMAL_PRECISION)
            .div(_totalEUSDSupply);

        uint256 newBaseRate = decayedBaseRate.add(
            redeemedEUSDFraction.div(BETA)
        );
        newBaseRate = ERDMath._min(newBaseRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%
        troveManager.updateBaseRate(newBaseRate);
        return newBaseRate;
    }

    function _getRedemptionFee(
        uint256 _collDrawnValue,
        uint256[] memory _collDrawns
    ) internal view returns (uint256, uint256[] memory) {
        return
            _calcRedemptionFee(
                troveManager.getRedemptionRate(),
                _collDrawnValue,
                _collDrawns
            );
    }

    function _calcRedemptionFee(
        uint256 _redemptionRate,
        uint256 _collDrawnValue,
        uint256[] memory _collDrawns
    ) internal pure returns (uint256, uint256[] memory) {
        uint256 redemptionFee = _redemptionRate.mul(_collDrawnValue).div(
            DECIMAL_PRECISION
        );
        require(
            redemptionFee < _collDrawnValue,
            "TroveManagerRedemptions: Fee would eat up all returned collateral"
        );
        uint256 length = _collDrawns.length;
        uint256[] memory redemptionFees = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            uint256 collDrawn = _collDrawns[i];
            if (collDrawn != 0) {
                redemptionFees[i] = _redemptionRate.mul(collDrawn).div(
                    DECIMAL_PRECISION
                );
                require(
                    redemptionFees[i] < collDrawn,
                    "TroveManagerRedemptions: Fee would eat up all returned collateral"
                );
            }
            unchecked {
                i++;
            }
        }
        return (redemptionFee, redemptionFees);
    }

    function MCR() internal view returns (uint256) {
        return collateralManager.getMCR();
    }

    function EUSD_GAS_COMPENSATION() internal view returns (uint256) {
        return collateralManager.getEUSDGasCompensation();
    }

    // --- 'require' wrapper functions ---

    function _requireIsContract(address _contract) internal view {
        require(
            _contract.isContract(),
            "TroveManagerRedemptions: Contract check error"
        );
    }

    function _requireCallerisTroveManager() internal view {
        require(
            msg.sender == address(troveManager),
            "TroveManagerLiquidations: Caller not TM"
        );
    }

    function _requireEUSDBalanceCoversRedemption(
        IEUSDToken _eusdToken,
        address _redeemer,
        uint256 _amount
    ) internal view {
        require(
            _eusdToken.balanceOf(_redeemer) >= _amount,
            "TroveManagerRedemptions: Requested redemption amount must be <= user's EUSD token balance"
        );
    }

    function _requireAmountGreaterThanZero(uint256 _amount) internal pure {
        require(
            _amount > 0,
            "TroveManagerRedemptions: Amount must be greater than zero"
        );
    }

    function _requireTCRoverMCR(uint256 _price) internal view {
        require(
            troveManager.getTCR(_price) >= MCR(),
            "TroveManagerRedemptions: Cannot redeem when TCR < MCR"
        );
    }

    function _requireAfterBootstrapPeriod() internal view {
        require(
            block.timestamp >=
                deploymentStartTime.add(collateralManager.getBootstrapPeriod()),
            "TroveManagerRedemptions: Redemptions are not allowed during bootstrap phase"
        );
    }

    function _requireValidMaxFeePercentage(
        uint256 _maxFeePercentage
    ) internal view {
        require(
            _maxFeePercentage >= collateralManager.getBorrowingFeeFloor() &&
                _maxFeePercentage <= DECIMAL_PRECISION,
            "Max fee percentage must be between 0.75% and 100%"
        );
    }

    function updateTroves(
        address[] calldata _borrowers,
        address[] calldata _lowerHints,
        address[] calldata _upperHints
    ) external override {
        uint256 lowerHintsLen = _lowerHints.length;
        require(
            lowerHintsLen == _upperHints.length &&
                lowerHintsLen == _borrowers.length,
            "TM: Length mismatch"
        );
        uint256 price = priceFeed.fetchPrice_view();
        for (uint256 i = 0; i < lowerHintsLen; i++) {
            _updateTrove(_borrowers[i], _lowerHints[i], _upperHints[i], price);
            // unchecked {
            //     i++;
            // }
        }
    }

    function _updateTrove(
        address _borrower,
        address _lowerHint,
        address _upperHint,
        uint256 _price
    ) internal {
        uint256 _ICR = troveManager.getCurrentICR(_borrower, _price);
        sortedTroves.reInsert(_borrower, _ICR, _lowerHint, _upperHint);
    }
}
