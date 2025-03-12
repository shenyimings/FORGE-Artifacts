// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./Interfaces/IBorrowerOperations.sol";
import "./Interfaces/IWETH.sol";
import "./Dependencies/ERDBase.sol";

contract BorrowerOperations is
    ERDBase,
    OwnableUpgradeable,
    IBorrowerOperations
{
    string public constant NAME = "BorrowerOperations";
    
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    // --- Connected contract declarations ---

    ITroveManager public troveManager;

    IWETH public WETH;

    address stabilityPoolAddress;

    ICollSurplusPool collSurplusPool;

    address public treasuryAddress;

    // A doubly linked list of Troves, sorted by their collateral ratios
    ISortedTroves public sortedTroves;

    /* --- Variable container structs  ---

    Used to hold, return and assign variables inside a function, in order to avoid the error:
    "CompilerError: Stack too deep". */

    struct AdjustTrove_Params {
        address borrower;
        address[] collsIn;
        uint256[] amountsIn;
        uint256[] sharesIn;
        address[] collsOut;
        uint256[] amountsOut;
        uint256[] sharesOut;
        uint256 EUSDChange;
        bool isDebtIncrease;
        address upperHint;
        address lowerHint;
        uint256 maxFeePercentage;
    }

    struct LocalVariables_adjustTrove {
        uint256 price;
        uint256 collChange;
        uint256 netDebtChange;
        bool isCollIncrease;
        uint256 debt;
        uint256[] colls;
        uint256[] shares;
        uint256[] newShares;
        uint256 oldICR;
        uint256 newICR;
        uint256 newTCR;
        uint256 EUSDFee;
        uint256 newDebt;
        uint256 valueIn;
        uint256 valueOut;
        uint256 currValue;
        uint256 newValue;
        address[] collaterals;
    }

    struct LocalVariables_openTrove {
        uint256 price;
        uint256 EUSDFee;
        uint256 netShare;
        uint256 netDebt;
        uint256 compositeDebt;
        uint256 ICR;
        uint256 value;
        uint256 arrayIndex;
        address[] collaterals;
        uint256[] netColls;
        uint256[] netShares;
    }

    // --- Dependency setters ---
    function initialize() public initializer {
        __Ownable_init();
    }

    function setAddresses(
        address _troveManagerAddress,
        address _collateralManagerAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _sortedTrovesAddress,
        address _eusdTokenAddress
    ) external override onlyOwner {
        _requireIsContract(_troveManagerAddress);
        _requireIsContract(_collateralManagerAddress);
        _requireIsContract(_activePoolAddress);
        _requireIsContract(_defaultPoolAddress);
        _requireIsContract(_stabilityPoolAddress);
        _requireIsContract(_gasPoolAddress);
        _requireIsContract(_collSurplusPoolAddress);
        _requireIsContract(_priceFeedAddress);
        _requireIsContract(_sortedTrovesAddress);
        _requireIsContract(_eusdTokenAddress);

        troveManager = ITroveManager(_troveManagerAddress);
        collateralManager = ICollateralManager(_collateralManagerAddress);
        activePool = IActivePool(_activePoolAddress);
        defaultPool = IDefaultPool(_defaultPoolAddress);
        stabilityPoolAddress = _stabilityPoolAddress;
        gasPoolAddress = _gasPoolAddress;
        collSurplusPool = ICollSurplusPool(_collSurplusPoolAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
        eusdToken = IEUSDToken(_eusdTokenAddress);

        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit CollateralManagerAddressChanged(_collateralManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);
        emit GasPoolAddressChanged(_gasPoolAddress);
        emit CollSurplusPoolAddressChanged(_collSurplusPoolAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);
        emit EUSDTokenAddressChanged(_eusdTokenAddress);
    }

    function init(
        address _wethAddress,
        address _treasuryAddress,
        address _troveDebtAddress
    ) external onlyOwner {
        _requireIsContract(_wethAddress);
        _requireIsContract(_treasuryAddress);
        _requireIsContract(_troveDebtAddress);

        WETH = IWETH(_wethAddress);
        treasuryAddress = _treasuryAddress;
        troveDebt = ITroveDebt(_troveDebtAddress);

        emit WETHAddressChanged(_wethAddress);
        emit TreasuryAddressChanged(_treasuryAddress);
        emit TroveDebtAddressChanged(_troveDebtAddress);
    }

    // --- Borrower Trove Operations ---

    function openTrove(
        address[] memory _colls,
        uint256[] memory _amounts,
        uint256 _maxFeePercentage,
        uint256 _EUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable override {
        if (msg.value == 0) {
            // Function require length nonzero, used to save contract size on revert strings.
            require(_amounts.length != 0, "BorrowerOps: Length is zero");
            _requireValidOpenTroveCollateral(_colls, _amounts);
        } else {
            _requireActiveCollateral(_colls);
        }

        LocalVariables_openTrove memory vars;
        (vars.collaterals, vars.netColls) = _adjustArray(
            _colls,
            _amounts,
            msg.value
        );

        _requireNoDuplicateColls(vars.collaterals);

        _activePoolAddColl(msg.sender, vars.collaterals, vars.netColls);

        ContractsCache memory contractsCache = ContractsCache(
            troveManager,
            collateralManager,
            activePool,
            eusdToken
        );

        // Update all collateral price
        vars.price = priceFeed.fetchPrice();
        contractsCache.collateralManager.priceUpdate();
        (vars.netShares, vars.value) = contractsCache
            .collateralManager
            .mintEToken(
                vars.collaterals,
                vars.netColls,
                msg.sender,
                vars.price
            );

        require(
            contractsCache.troveManager.getTroveStatus(msg.sender) != 1,
            "BorrowerOps: Trove is active"
        );

        bool isRecoveryMode = contractsCache.troveManager.checkRecoveryMode(
            vars.price
        );

        _requireValidMaxFeePercentage(_maxFeePercentage, isRecoveryMode);

        vars.EUSDFee;
        vars.netDebt = _EUSDAmount;

        // Different borrowing fee for different mode
        vars.EUSDFee = _triggerBorrowingFee(
            contractsCache.troveManager,
            contractsCache.eusdToken,
            _EUSDAmount,
            _maxFeePercentage,
            isRecoveryMode
        );
        vars.netDebt = vars.netDebt.add(vars.EUSDFee);
        _requireAtLeastMinNetDebt(vars.netDebt);

        // ICR is based on the composite debt, i.e. the requested EUSD amount + EUSD borrowing fee + EUSD gas comp.
        uint256 gas = EUSD_GAS_COMPENSATION();
        vars.compositeDebt = _getCompositeDebt(vars.netDebt, gas);
        assert(vars.compositeDebt > 0);

        vars.ICR = ERDMath._computeCR(vars.value, vars.compositeDebt);

        if (isRecoveryMode) {
            _requireICRisAboveCCR(vars.ICR);
        } else {
            _requireICRisAboveMCR(vars.ICR);
            // collateral already transfer to activePool
            // pass collChange = 0 to function
            uint256 newTCR = _getNewTCRFromTroveChange(
                vars.compositeDebt,
                true,
                vars.price
            ); // bools: coll increase, debt increase

            _requireNewTCRisAboveCCR(newTCR);
        }
        // Set the trove struct's properties
        contractsCache.troveManager.setTroveStatus(msg.sender, 1);

        contractsCache.troveManager.increaseTroveDebt(msg.sender, vars.netDebt);
        contractsCache.troveManager.updateTroveRewardSnapshots(msg.sender);
        contractsCache.troveManager.updateStakeAndTotalStakes(msg.sender);

        sortedTroves.insert(msg.sender, vars.ICR, _upperHint, _lowerHint);
        vars.arrayIndex = contractsCache.troveManager.addTroveOwnerToArray(
            msg.sender
        );
        emit TroveCreated(msg.sender, vars.arrayIndex);

        // Move the collateral to the Active Pool, and mint the EUSDAmount to the borrower
        _withdrawEUSD(
            contractsCache.activePool,
            contractsCache.eusdToken,
            msg.sender,
            _EUSDAmount,
            vars.netDebt
        );
        // Move the EUSD gas compensation to the Gas Pool
        _withdrawEUSD(
            contractsCache.activePool,
            contractsCache.eusdToken,
            gasPoolAddress,
            gas,
            gas
        );

        emit TroveUpdated(
            msg.sender,
            vars.compositeDebt,
            vars.collaterals,
            vars.netShares,
            vars.netColls,
            BorrowerOperation.openTrove
        );
        emit EUSDBorrowingFeePaid(msg.sender, vars.EUSDFee);
    }

    function _adjustArray(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        uint256 _amount
    ) public view returns (address[] memory, uint256[] memory) {
        uint256 collLen = _collaterals.length;
        if (collLen == 0 && _amount > 0) {
            address[] memory collaterals = new address[](1);
            uint256[] memory amounts = new uint256[](1);
            collaterals[0] = address(WETH);
            amounts[0] = _amount;
            return (collaterals, amounts);
        }
        if (_amount > 0) {
            address[] memory collaterals = new address[](collLen + 1);
            uint256[] memory amounts = new uint256[](collLen + 1);
            collaterals[0] = address(WETH);
            amounts[0] = _amount;
            address collateral;
            bool hasWETH;
            uint256 index;
            for (uint256 i = 0; i < collLen; i++) {
                collateral = _collaterals[i];
                if (collateral != address(WETH)) {
                    collaterals[i + 1] = collateral;
                    amounts[i + 1] = _amounts[i];
                } else {
                    hasWETH = true;
                    index = i;
                    break;
                }
                // unchecked {
                //     i++;
                // }
            }
            if (hasWETH) {
                _amounts[index] = _amounts[index].add(_amount);
                return (_collaterals, _amounts);
            } else {
                return (collaterals, amounts);
            }
        } else {
            return (_collaterals, _amounts);
        }
    }

    // Send collateral to a trove
    function addColl(
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address _upperHint,
        address _lowerHint
    ) external payable override {
        AdjustTrove_Params memory params;
        params.borrower = msg.sender;
        if (msg.value == 0) {
            _requireValidAdjustCollateralAmounts(_collsIn, _amountsIn);
            _requireNoDuplicateColls(_collsIn);
        } else {
            _requireSupportCollateral(_collsIn);
        }

        (params.collsIn, params.amountsIn) = _adjustArray(
            _collsIn,
            _amountsIn,
            msg.value
        );

        _activePoolAddColl(msg.sender, params.collsIn, params.amountsIn);
        params.sharesIn = collateralManager.getShares(
            params.collsIn,
            params.amountsIn
        );
        params.upperHint = _upperHint;
        params.lowerHint = _lowerHint;
        _adjustTrove(params);
    }

    // Withdraw collateral from a trove
    function withdrawColl(
        address[] memory _collsOut,
        uint256[] memory _amountsOut,
        address _upperHint,
        address _lowerHint
    ) external override {
        AdjustTrove_Params memory params;
        params.borrower = msg.sender;
        params.collsOut = _collsOut;
        params.amountsOut = _amountsOut;
        params.upperHint = _upperHint;
        params.lowerHint = _lowerHint;

        _requireValidAdjustCollateralAmounts(
            params.collsOut,
            params.amountsOut
        );
        _requireNoDuplicateColls(params.collsOut);
        params.sharesOut = collateralManager.getShares(
            params.collsOut,
            params.amountsOut
        );

        _adjustTrove(params);
    }

    // Withdraw EUSD tokens from a trove: mint new EUSD tokens to the owner, and increase the trove's debt accordingly
    function withdrawEUSD(
        uint256 _EUSDAmount,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFeePercentage
    ) external override {
        AdjustTrove_Params memory params;
        params.borrower = msg.sender;
        params.EUSDChange = _EUSDAmount;
        params.maxFeePercentage = _maxFeePercentage;
        params.upperHint = _upperHint;
        params.lowerHint = _lowerHint;
        params.isDebtIncrease = true;
        _adjustTrove(params);
    }

    // Repay EUSD tokens to a Trove: Burn the repaid EUSD tokens, and reduce the trove's debt accordingly
    function repayEUSD(
        uint256 _EUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external override {
        AdjustTrove_Params memory params;
        params.borrower = msg.sender;
        params.EUSDChange = _EUSDAmount;
        params.upperHint = _upperHint;
        params.lowerHint = _lowerHint;
        params.isDebtIncrease = false;
        _adjustTrove(params);
    }

    // Send collateral to a trove. Called by only the Stability Pool.
    function moveCollGainToTrove(
        address _borrower,
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address _upperHint,
        address _lowerHint
    ) external override {
        require(
            msg.sender == stabilityPoolAddress,
            "BorrowerOps: Caller is not Stability Pool"
        );
        AdjustTrove_Params memory params;
        params.borrower = _borrower;
        params.collsIn = _collsIn;
        params.amountsIn = _amountsIn;
        params.upperHint = _upperHint;
        params.lowerHint = _lowerHint;

        _requireValidAdjustCollateralAmounts(params.collsIn, params.amountsIn);
        _requireNoDuplicateColls(params.collsIn);
        params.sharesIn = collateralManager.getShares(
            params.collsIn,
            params.amountsIn
        );

        _activePoolAddColl(msg.sender, params.collsIn, params.amountsIn);

        _adjustTrove(params);
    }

    function adjustTrove(
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address[] memory _collsOut,
        uint256[] memory _amountsOut,
        uint256 _maxFeePercentage,
        uint256 _EUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable override {
        if (msg.value == 0) {
            _requireValidAdjustCollateralAmounts(_collsIn, _amountsIn);
            _requireValidAdjustCollateralAmounts(_collsOut, _amountsOut);
            _requireNoOverlapColls(_collsIn, _collsOut);
            _requireNoDuplicateColls(_collsIn);
            _requireNoDuplicateColls(_collsOut);
        } else {
            _requireSupportCollateral(_collsIn);
            _requireSupportCollateral(_collsOut);
            _requireNoWETHColls(_collsOut);
        }

        (
            address[] memory adjustCollsIn,
            uint256[] memory adjustAmountsIn
        ) = _adjustArray(_collsIn, _amountsIn, msg.value);

        uint256[] memory adjustSharesIn = collateralManager.getShares(
            adjustCollsIn,
            adjustAmountsIn
        );
        uint256[] memory adjustSharesOut = collateralManager.getShares(
            _collsOut,
            _amountsOut
        );

        _activePoolAddColl(msg.sender, adjustCollsIn, adjustAmountsIn);
        AdjustTrove_Params memory params = AdjustTrove_Params({
            borrower: msg.sender,
            collsIn: adjustCollsIn,
            amountsIn: adjustAmountsIn,
            sharesIn: adjustSharesIn,
            collsOut: _collsOut,
            amountsOut: _amountsOut,
            sharesOut: adjustSharesOut,
            EUSDChange: _EUSDChange,
            isDebtIncrease: _isDebtIncrease,
            upperHint: _upperHint,
            lowerHint: _lowerHint,
            maxFeePercentage: _maxFeePercentage
        });
        _adjustTrove(params);
    }

    /*
     * _adjustTrove(): Alongside a debt change, this function can perform either a collateral top-up or a collateral withdrawal.
     *
     * It therefore expects either a positive msg.value, or a positive _collWithdrawal argument.
     *
     * If both are positive, it will revert.
     */
    function _adjustTrove(AdjustTrove_Params memory params) internal {
        ContractsCache memory contractsCache = ContractsCache(
            troveManager,
            collateralManager,
            activePool,
            eusdToken
        );
        LocalVariables_adjustTrove memory vars;

        vars.price = priceFeed.fetchPrice();
        contractsCache.collateralManager.priceUpdate();
        bool isRecoveryMode = contractsCache.troveManager.checkRecoveryMode(
            vars.price
        );
        if (params.isDebtIncrease) {
            _requireValidMaxFeePercentage(
                params.maxFeePercentage,
                isRecoveryMode
            );
            require(
                params.EUSDChange > 0,
                "BorrowerOps: Debt increase requires non-zero debtChange"
            );
        }
        _requireNonZeroAdjustment(
            params.amountsIn,
            params.amountsOut,
            params.EUSDChange
        );
        _requireTroveisActive(contractsCache.troveManager, params.borrower);
        // Confirm the operation is either a borrower adjusting their own trove, or a pure collateral transfer from the Stability Pool to a trove
        assert(
            msg.sender == params.borrower ||
                (msg.sender == stabilityPoolAddress &&
                    params.amountsIn.length > 0 /* TODO:  necessary? */ &&
                    params.EUSDChange == 0)
        );

        contractsCache.troveManager.applyPendingRewards(params.borrower);

        (vars.colls, vars.shares, vars.collaterals) = contractsCache
            .troveManager
            .getTroveColls(params.borrower);

        (vars.currValue, ) = contractsCache.collateralManager.getValue(
            vars.collaterals,
            vars.colls,
            vars.price
        );

        (, vars.valueIn) = contractsCache.collateralManager.mintEToken(
            params.collsIn,
            params.amountsIn,
            params.borrower,
            vars.price
        );

        (, vars.valueOut) = contractsCache.collateralManager.burnEToken(
            params.collsOut,
            params.amountsOut,
            params.borrower,
            vars.price
        );

        vars.netDebtChange = params.EUSDChange;

        // If the adjustment incorporates a debt increase and system is in Normal Mode, then trigger a borrowing fee
        if (params.isDebtIncrease) {
            vars.EUSDFee = _triggerBorrowingFee(
                contractsCache.troveManager,
                contractsCache.eusdToken,
                params.EUSDChange,
                params.maxFeePercentage,
                isRecoveryMode
            );
            vars.netDebtChange = vars.netDebtChange.add(vars.EUSDFee); // The raw debt change includes the fee
        }

        vars.debt = contractsCache.troveManager.getTroveDebt(params.borrower);

        (vars.newValue, vars.newDebt) = _getNewTroveAmounts(
            vars.currValue,
            vars.debt,
            vars.valueIn,
            vars.valueOut,
            vars.netDebtChange,
            params.isDebtIncrease
        );

        // Get the collChange based on whether or not collateral was sent in the transaction
        vars.isCollIncrease = vars.newValue > vars.currValue;
        vars.collChange = vars.isCollIncrease
            ? vars.newValue.sub(vars.currValue)
            : vars.currValue.sub(vars.newValue);

        // Get the trove's old ICR before the adjustment, and what its new ICR will be after the adjustment
        vars.oldICR = ERDMath._computeCR(vars.currValue, vars.debt);
        vars.newICR = ERDMath._computeCR(vars.newValue, vars.newDebt);

        // Check the adjustment satisfies all conditions for the current system mode
        _requireValidAdjustmentInCurrentMode(
            isRecoveryMode,
            params.amountsOut,
            params.isDebtIncrease,
            vars
        );

        // When the adjustment is a debt repayment, check it's a valid amount and that the caller has enough EUSD
        if (!params.isDebtIncrease && params.EUSDChange > 0) {
            _requireAtLeastMinNetDebt(
                _getNetDebt(vars.debt, EUSD_GAS_COMPENSATION()).sub(
                    vars.netDebtChange
                )
            );
            _requireValidEUSDRepayment(vars.debt, vars.netDebtChange);
            _requireSufficientEUSDBalance(
                contractsCache.eusdToken,
                params.borrower,
                vars.netDebtChange
            );
        }

        _updateTroveFromAdjustment(
            contractsCache.troveManager,
            params.borrower,
            vars.netDebtChange,
            params.isDebtIncrease
        );
        contractsCache.troveManager.updateStakeAndTotalStakes(params.borrower);

        // Re-insert trove in to the sorted list
        sortedTroves.reInsert(
            params.borrower,
            vars.newICR,
            params.upperHint,
            params.lowerHint
        );

        (vars.colls, vars.newShares, ) = contractsCache
            .troveManager
            .getTroveColls(params.borrower);

        emit TroveUpdated(
            params.borrower,
            vars.newDebt,
            vars.collaterals,
            vars.newShares,
            vars.colls,
            BorrowerOperation.adjustTrove
        );
        emit EUSDBorrowingFeePaid(msg.sender, vars.EUSDFee);

        // Use the unmodified _EUSDChange here, as we don't send the fee to the user
        _moveTokensAndCollateralfromAdjustment(
            contractsCache.activePool,
            contractsCache.eusdToken,
            msg.sender,
            params.collsOut,
            params.amountsOut,
            params.EUSDChange,
            params.isDebtIncrease,
            vars.netDebtChange
        );
    }

    function closeTrove() external override {
        ITroveManager troveManagerCached = troveManager;
        ICollateralManager collateralManagerCached = collateralManager;
        IActivePool activePoolCached = activePool;
        IEUSDToken eusdTokenCached = eusdToken;

        _requireTroveisActive(troveManagerCached, msg.sender);
        uint256 price = priceFeed.fetchPrice();
        collateralManagerCached.priceUpdate();
        require(
            !troveManager.checkRecoveryMode(price),
            "BorrowerOps: Operation not permitted during Recovery Mode"
        );

        troveManagerCached.applyPendingRewards(msg.sender);

        (
            uint256[] memory collAmounts,
            ,
            address[] memory collaterals
        ) = collateralManagerCached.getTroveColls(msg.sender);

        collateralManagerCached.burnEToken(
            collaterals,
            collAmounts,
            msg.sender,
            0
        );
        uint256 debt = troveManagerCached.getTroveDebt(msg.sender);
        
        uint256 gas = EUSD_GAS_COMPENSATION();
        _requireSufficientEUSDBalance(
            eusdTokenCached,
            msg.sender,
            debt.sub(gas)
        );

        uint256 newTCR = _getNewTCRFromTroveChange(debt, false, price);
        _requireNewTCRisAboveCCR(newTCR);

        troveManagerCached.removeStake(msg.sender);
        troveManagerCached.closeTrove(msg.sender);

        emit TroveUpdated(
            msg.sender,
            0,
            new address[](0),
            new uint256[](0),
            new uint256[](0),
            BorrowerOperation.closeTrove
        );

        // Burn the repaid EUSD from the user's balance and the gas compensation from the Gas Pool
        _repayEUSD(
            activePoolCached,
            eusdTokenCached,
            msg.sender,
            debt.sub(gas)
        );
        _repayEUSD(activePoolCached, eusdTokenCached, gasPoolAddress, gas);

        // Send the collateral back to the user
        activePoolCached.sendCollateral(msg.sender, collaterals, collAmounts);
    }

    /**
     * Claim remaining collateral from a redemption or from a liquidation with ICR > MCR in Recovery Mode
     */
    function claimCollateral() external override {
        // send collateral from CollSurplus Pool to owner
        collSurplusPool.claimColl(msg.sender);
    }

    // --- Helper functions ---

    // Send collateral to Active Pool and increase its recorded collateral balance
    function _activePoolAddColl(
        address _from,
        address[] memory _colls,
        uint256[] memory _amounts
    ) internal {
        uint256 amountsLen = _amounts.length;
        address collAddress;
        uint256 amount;
        for (uint256 i; i < amountsLen; i++) {
            collAddress = _colls[i];
            amount = _amounts[i];
            _singleTransferCollateralIntoActivePool(_from, collAddress, amount);
            // unchecked {
            //     i++;
            // }
        }
    }

    // does one transfer of collateral into active pool. Checks that it transferred to the active pool correctly.
    function _singleTransferCollateralIntoActivePool(
        address _from,
        address _coll,
        uint256 _amount
    ) internal {
        if (_coll == address(WETH)) {
            if (_from != stabilityPoolAddress) {
                WETH.deposit{value: msg.value}();
                WETH.transferFrom(address(this), address(activePool), _amount);
            } else {
                SafeERC20Upgradeable.safeTransferFrom(
                    IERC20Upgradeable(_coll),
                    _from,
                    address(activePool),
                    _amount
                );
            }
        } else {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(_coll),
                _from,
                address(activePool),
                _amount
            );
        }
    }

    function _triggerBorrowingFee(
        ITroveManager _troveManager,
        IEUSDToken _eusdToken,
        uint256 _EUSDAmount,
        uint256 _maxFeePercentage,
        bool _isRecoveryMode
    ) internal returns (uint256) {
        uint256 EUSDFee;
        if (!_isRecoveryMode) {
            _troveManager.decayBaseRateFromBorrowing(); // decay the baseRate state variable
            EUSDFee = _troveManager.getBorrowingFee(_EUSDAmount);
        } else {
            uint256 rate = collateralManager.getRecoveryFee();
            EUSDFee = rate.mul(_EUSDAmount).div(DECIMAL_PRECISION);
        }

        _requireUserAcceptsFee(EUSDFee, _EUSDAmount, _maxFeePercentage);

        // Send fee to treasury contract
        _eusdToken.mintToTreasury(EUSDFee, _troveManager.getFactor());
        
        return EUSDFee;
    }

    // Update trove's coll and debt based on whether they increase or decrease
    function _updateTroveFromAdjustment(
        ITroveManager _troveManager,
        address _borrower,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal {
        if (_debtChange > 0) {
            if (_isDebtIncrease) {
                _troveManager.increaseTroveDebt(_borrower, _debtChange);
            } else {
                _troveManager.decreaseTroveDebt(_borrower, _debtChange);
            }
        }
    }

    function _moveTokensAndCollateralfromAdjustment(
        IActivePool _activePool,
        IEUSDToken _eusdToken,
        address _borrower,
        address[] memory _collaterals,
        uint256[] memory _amountsOut,
        uint256 _EUSDChange,
        bool _isDebtIncrease,
        uint256 _netDebtChange
    ) internal {
        if (_isDebtIncrease) {
            _withdrawEUSD(
                _activePool,
                _eusdToken,
                _borrower,
                _EUSDChange,
                _netDebtChange
            );
        } else {
            _repayEUSD(_activePool, _eusdToken, _borrower, _EUSDChange);
        }
        _activePool.sendCollateral(_borrower, _collaterals, _amountsOut);
    }

    // Issue the specified amount of EUSD to _account and increases the total active debt (_netDebtIncrease potentially includes a EUSDFee)
    function _withdrawEUSD(
        IActivePool _activePool,
        IEUSDToken _eusdToken,
        address _account,
        uint256 _EUSDAmount,
        uint256 _netDebtIncrease
    ) internal {
        _activePool.increaseEUSDDebt(_netDebtIncrease);
        _eusdToken.mint(_account, _EUSDAmount);
    }

    // Burn the specified amount of EUSD from _account and decreases the total active debt
    function _repayEUSD(
        IActivePool _activePool,
        IEUSDToken _eusdToken,
        address _account,
        uint256 _EUSD
    ) internal {
        _activePool.decreaseEUSDDebt(_EUSD);
        _eusdToken.burn(_account, _EUSD);
    }

    // --- 'Require' wrapper functions ---

    function _requireIsContract(address _contract) internal view {
        require(_contract.isContract(), "BorrowerOps: Contract check error");
    }

    function _requireValidOpenTroveCollateral(
        address[] memory _colls,
        uint256[] memory _amounts
    ) internal view {
        uint256 collsLen = _colls.length;
        _requireLengthsEqual(collsLen, _amounts.length);
        for (uint256 i; i < collsLen; i++) {
            require(
                collateralManager.getIsActive(_colls[i]),
                "BorrowerOps: Collateral does not active or is paused"
            );
            require(_amounts[i] != 0, "BorrowerOps: Collateral amount is 0");
        }
    }

    function _requireActiveCollateral(address[] memory _colls) internal view {
        uint256 collsLen = _colls.length;
        for (uint256 i = 0; i < collsLen; i++) {
            require(
                collateralManager.getIsActive(_colls[i]),
                "BorrowerOps: Collateral does not active or is paused"
            );
        }
    }

    function _requireValidAdjustCollateralAmounts(
        address[] memory _colls,
        uint256[] memory _amounts
    ) internal view {
        uint256 collsLen = _colls.length;
        _requireLengthsEqual(collsLen, _amounts.length);
        for (uint256 i; i < collsLen; ++i) {
            require(
                collateralManager.getIsSupport(_colls[i]),
                "BorrowerOps: Collateral does not support"
            );
            require(_amounts[i] != 0, "BorrowerOps: Collateral amount is 0");
        }
    }

    function _requireSupportCollateral(address[] memory _colls) internal view {
        uint256 collsLen = _colls.length;
        for (uint256 i = 0; i < collsLen; i++) {
            require(
                collateralManager.getIsSupport(_colls[i]),
                "BorrowerOps: Collateral does not support"
            );
        }
    }

    function _requireNoOverlapColls(
        address[] memory _colls1,
        address[] memory _colls2
    ) internal pure {
        uint256 colls1Len = _colls1.length;
        uint256 colls2Len = _colls2.length;
        for (uint256 i; i < colls1Len; ++i) {
            for (uint256 j; j < colls2Len; j++) {
                require(_colls1[i] != _colls2[j], "BorrowerOps: Overlap Colls");
            }
        }
    }

    function _requireNoWETHColls(address[] memory _colls) internal view {
        uint256 collsLen = _colls.length;
        for (uint256 i; i < collsLen; ++i) {
            require(
                _colls[i] != address(WETH),
                "BorrowerOps: Cannot withdraw and add Coll"
            );
        }
    }

    function _requireNoDuplicateColls(address[] memory _colls) internal pure {
        uint256 collsLen = _colls.length;
        for (uint256 i; i < collsLen; ++i) {
            for (uint256 j = i.add(1); j < collsLen; j++) {
                require(_colls[i] != _colls[j], "BorrowerOps: Duplicate Colls");
            }
        }
    }

    function _requireNonZeroAdjustment(
        uint256[] memory _amountsIn,
        uint256[] memory _amountsOut,
        uint256 _EUSDChange
    ) internal pure {
        require(
            ERDMath._arrayIsNonzero(_amountsIn) ||
                ERDMath._arrayIsNonzero(_amountsOut) ||
                _EUSDChange != 0,
            "BorrowerOps: There must be either a collateral change or a debt change"
        );
    }

    function _requireTroveisActive(
        ITroveManager _troveManager,
        address _borrower
    ) internal view {
        uint256 status = _troveManager.getTroveStatus(_borrower);
        require(status == 1, "BorrowerOps: Trove does not exist or is closed");
    }

    function _requireTroveisNotActive(
        ITroveManager _troveManager,
        address _borrower
    ) internal view {
        uint256 status = _troveManager.getTroveStatus(_borrower);
        require(status != 1, "BorrowerOps: Trove is active");
    }

    function _requireValidAdjustmentInCurrentMode(
        bool _isRecoveryMode,
        uint256[] memory _collWithdrawals,
        bool _isDebtIncrease,
        LocalVariables_adjustTrove memory _vars
    ) internal view {
        /*
         *In Recovery Mode, only allow:
         *
         * - Pure collateral top-up
         * - Pure debt repayment
         * - Collateral top-up with debt repayment
         * - A debt increase combined with a collateral top-up which makes the ICR >= 150% and improves the ICR (and by extension improves the TCR).
         *
         * In Normal Mode, ensure:
         *
         * - The new ICR is above MCR
         * - The adjustment won't pull the TCR below CCR
         */
        if (_isRecoveryMode) {
            require(
                !ERDMath._arrayIsNonzero(_collWithdrawals),
                "BorrowerOps: Collateral withdrawal not permitted Recovery Mode"
            );
            if (_isDebtIncrease) {
                _requireICRisAboveCCR(_vars.newICR);
                _requireNewICRisAboveOldICR(_vars.newICR, _vars.oldICR);
            }
        } else {
            // if Normal Mode
            _requireICRisAboveMCR(_vars.newICR);
            _vars.newTCR = _getNewTCRFromTroveChange(
                _vars.netDebtChange,
                _isDebtIncrease,
                _vars.price
            );
            _requireNewTCRisAboveCCR(_vars.newTCR);
        }
    }

    function _requireICRisAboveMCR(uint256 _newICR) internal view {
        require(
            _newICR >= collateralManager.getMCR(),
            "BorrowerOps: An operation that would result in ICR < MCR is not permitted"
        );
    }

    function _requireICRisAboveCCR(uint256 _newICR) internal view {
        require(
            _newICR >= CCR(),
            "BorrowerOps: Operation must leave trove with ICR >= CCR"
        );
    }

    function _requireNewICRisAboveOldICR(
        uint256 _newICR,
        uint256 _oldICR
    ) internal pure {
        require(
            _newICR >= _oldICR,
            "BorrowerOps: Cannot decrease your Trove's ICR in Recovery Mode"
        );
    }

    function _requireNewTCRisAboveCCR(uint256 _newTCR) internal view {
        require(
            _newTCR >= CCR(),
            "BorrowerOps: An operation that would result in TCR < CCR is not permitted"
        );
    }

    function _requireAtLeastMinNetDebt(uint256 _netDebt) internal view {
        require(
            _netDebt >= MIN_NET_DEBT(),
            "BorrowerOps: Trove's net debt must be greater than minimum"
        );
    }

    function _requireValidEUSDRepayment(
        uint256 _currentDebt,
        uint256 _debtRepayment
    ) internal view {
        require(
            _debtRepayment <= _currentDebt.sub(EUSD_GAS_COMPENSATION()),
            "BorrowerOps: Amount repaid must not be larger than the Trove's debt"
        );
    }

    function _requireSufficientEUSDBalance(
        IEUSDToken _eusdToken,
        address _borrower,
        uint256 _debtRepayment
    ) internal view {
        require(
            _eusdToken.balanceOf(_borrower) >= _debtRepayment,
            "BorrowerOps: Caller doesnt have enough EUSD to make repayment"
        );
    }

    function _requireValidMaxFeePercentage(
        uint256 _maxFeePercentage,
        bool _isRecoveryMode
    ) internal view {
        if (_isRecoveryMode) {
            require(
                _maxFeePercentage <= DECIMAL_PRECISION,
                "Max fee percentage must less than or equal to 100%"
            );
        } else {
            require(
                _maxFeePercentage >= collateralManager.getBorrowingFeeFloor() &&
                    _maxFeePercentage <= DECIMAL_PRECISION,
                "Max fee percentage must be between 0.75% and 100%"
            );
        }
    }

    // Function require length equal, used to save contract size on revert strings.
    function _requireLengthsEqual(
        uint256 length1,
        uint256 length2
    ) internal pure {
        require(length1 == length2, "BorrowerOps: Length mismatch");
    }

    // Compute the new collateral & debt, considering the change in coll and debt. Assumes 0 pending rewards.

    function _getNewTroveAmounts(
        uint256 _coll,
        uint256 _debt,
        uint256 _valueIn,
        uint256 _valueOut,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal pure returns (uint256 newValue, uint256 newDebt) {
        newValue = _coll.add(_valueIn).sub(_valueOut);
        newDebt = _isDebtIncrease
            ? _debt.add(_debtChange)
            : _debt.sub(_debtChange);
    }

    function _getNewTCRFromTroveChange(
        uint256 _debtChange,
        bool _isDebtIncrease,
        uint256 _price
    ) internal view returns (uint256) {
        (, , uint256 totalValue) = getEntireSystemColl(_price);
        uint256 totalDebt = getEntireSystemDebt();

        totalDebt = _isDebtIncrease
            ? totalDebt.add(_debtChange)
            : totalDebt.sub(_debtChange);

        uint256 newTCR = ERDMath._computeCR(totalValue, totalDebt);
        return newTCR;
    }

    function getCompositeDebt(
        uint256 _debt
    ) external view override returns (uint256) {
        return _getCompositeDebt(_debt, EUSD_GAS_COMPENSATION());
    }

    function MIN_NET_DEBT() public view returns (uint256) {
        return collateralManager.getMinNetDebt();
    }

    function CCR() internal view returns (uint256) {
        return collateralManager.getCCR();
    }

    function EUSD_GAS_COMPENSATION() public view returns (uint256) {
        return collateralManager.getEUSDGasCompensation();
    }
}
