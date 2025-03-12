// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./TroveManagerDataTypes.sol";
import "./DataTypes.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/ICollateralManager.sol";
import "./Interfaces/IPriceFeed.sol";
import "./Interfaces/IOracle.sol";
import "./Interfaces/IEToken.sol";

contract CollateralManager is
    OwnableUpgradeable,
    TroveManagerDataTypes,
    ICollateralManager
{
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    // During bootsrap period redemptions are not allowed
    uint256 public BOOTSTRAP_PERIOD;

    // Minimum collateral ratio for individual troves
    uint256 public MCR;

    // Critical system collateral ratio. If the system's total collateral ratio (TCR) falls below the CCR, Recovery Mode is triggered.
    uint256 public CCR;

    // Amount of EUSD to be locked in gas pool on opening troves
    uint256 public EUSD_GAS_COMPENSATION;

    // Minimum amount of net EUSD debt a trove must have
    uint256 public MIN_NET_DEBT;

    uint256 public BORROWING_FEE_FLOOR;

    uint256 public REDEMPTION_FEE_FLOOR;
    uint256 public RECOVERY_FEE;
    uint256 public MAX_BORROWING_FEE;

    address public borrowerOperationsAddress;
    address public troveManagerRedemptionsAddress;
    address public wethAddress;

    ITroveManager internal troveManager;

    mapping(address => DataTypes.CollateralParams) public collateralParams;

    // The array of collaterals that support,
    // index 0 represents the highest priority,
    // the lowest priority collateral in the same trove will be prioritized for liquidation or redemption
    address[] public collateralSupport;

    uint256 public collateralsCount;

    function initialize() public initializer {
        __Ownable_init();
        BOOTSTRAP_PERIOD = 14 days;
        MCR = 1100000000000000000; // 110%
        CCR = 1300000000000000000; // 130%
        EUSD_GAS_COMPENSATION = 200e18;
        MIN_NET_DEBT = 1800e18;
        BORROWING_FEE_FLOOR = (DECIMAL_PRECISION / 10000) * 75; // 0.75%

        REDEMPTION_FEE_FLOOR = (DECIMAL_PRECISION / 10000) * 75; // 0.75%
        RECOVERY_FEE = (DECIMAL_PRECISION / 10000) * 25; // 0.25%
        MAX_BORROWING_FEE = (DECIMAL_PRECISION / 100) * 5; // 5%
    }

    function setAddresses(
        address _activePoolAddress,
        address _borrowerOperationsAddress,
        address _defaultPoolAddress,
        address _priceFeedAddress,
        address _troveManagerAddress,
        address _troveManagerRedemptionsAddress,
        address _wethAddress
    ) external override onlyOwner {
        _requireIsContract(_activePoolAddress);
        _requireIsContract(_borrowerOperationsAddress);
        _requireIsContract(_defaultPoolAddress);
        _requireIsContract(_priceFeedAddress);
        _requireIsContract(_wethAddress);
        _requireIsContract(_troveManagerAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        activePool = IActivePool(_activePoolAddress);
        defaultPool = IDefaultPool(_defaultPoolAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        wethAddress = _wethAddress;

        troveManager = ITroveManager(_troveManagerAddress);

        troveManagerRedemptionsAddress = _troveManagerRedemptionsAddress;

        emit ActivePoolAddressChanged(_activePoolAddress);
        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit TroveManagerRedemptionsAddressChanged(
            _troveManagerRedemptionsAddress
        );
        emit WETHAddressChanged(_wethAddress);
    }

    function addCollateral(
        address _collateral,
        address _oracle,
        address _eTokenAddress,
        uint256 _ratio
    ) external override onlyOwner {
        require(
            !getIsSupport(_collateral),
            "CollateralManager: Collateral already exists"
        );
        _requireRatioLegal(_ratio);

        collateralParams[_collateral] = DataTypes.CollateralParams(
            _ratio,
            _eTokenAddress,
            _oracle,
            DataTypes.CollStatus(1),
            collateralsCount
        );
        collateralSupport.push(_collateral);
        collateralsCount = collateralsCount.add(1);
    }

    function removeCollateral(address _collateral) external override onlyOwner {
        address collAddress = _collateral;
        require(
            getIsSupport(collAddress) && !getIsActive(collAddress),
            "CollateralManager: Collateral not pause"
        );
        require(
            collateralsCount > 1,
            "CollateralManager: Need at least one collateral support"
        );
        uint256 index = getIndex(collAddress);
        address collateral;
        for (uint256 i = index; i < collateralsCount - 1; ) {
            collateral = collateralSupport[i];
            collateralSupport[i] = collateralSupport[i + 1];
            collateralSupport[i + 1] = collateral;
            collateralParams[collateralSupport[i]].index = i;
            unchecked {
                i++;
            }
        }
        collateralSupport.pop();
        collateralsCount = collateralsCount.sub(1);
        delete collateralParams[collAddress];
    }

    function setCollateralPriority(
        address _collateral,
        uint256 _newIndex
    ) external override onlyOwner {
        _requireCollIsActive(_collateral);
        uint256 oldIndex = getIndex(_collateral);
        uint256 newIndex = _newIndex;
        assert(newIndex != oldIndex && newIndex < collateralsCount);
        if (newIndex < oldIndex) {
            uint256 tmpIndex = oldIndex;
            uint256 gap = oldIndex - newIndex;
            for (uint256 i = 0; i < gap; ) {
                tmpIndex = _up(tmpIndex);
                unchecked {
                    i++;
                }
            }
        } else {
            uint256 tmpIndex = newIndex;
            uint256 gap = oldIndex - newIndex;
            for (uint256 i = 0; i < gap; ) {
                tmpIndex = _down(tmpIndex);
                unchecked {
                    i++;
                }
            }
        }
        collateralParams[_collateral].index = _newIndex;
    }

    function _up(uint256 _index) internal returns (uint256) {
        uint256 index = _index;
        _swap(index, index - 1);
        return index - 1;
    }

    function _down(uint256 _index) internal returns (uint256) {
        uint256 index = _index;
        _swap(index, index + 1);
        return index + 1;
    }

    function _swap(uint256 _x, uint256 _y) internal {
        address collateral = collateralSupport[_x];
        collateralSupport[_y] = collateralSupport[_x];
        collateralSupport[_x] = collateral;
    }

    function pauseCollateral(address _collateral) external override onlyOwner {
        _setStatus(_collateral, 2);
    }

    function activeCollateral(address _collateral) external override onlyOwner {
        _setStatus(_collateral, 1);
    }

    function _setStatus(address _collateral, uint256 _num) internal {
        collateralParams[_collateral].status = DataTypes.CollStatus(_num);
    }

    function setOracle(
        address _collateral,
        address _oracle
    ) public override onlyOwner {
        collateralParams[_collateral].oracle = _oracle;
    }

    function setEToken(
        address _collateral,
        address _eTokenAddress
    ) public override onlyOwner {
        collateralParams[_collateral].eToken = _eTokenAddress;
    }

    function setRatio(
        address _collateral,
        uint256 _ratio
    ) public override onlyOwner {
        _requireCollIsActive(_collateral);
        _requireRatioLegal(_ratio);
        collateralParams[_collateral].ratio = _ratio;
    }

    function priceUpdate() external override {
        if (collateralsCount < 3) {
            return;
        }
        for (uint256 i = 1; i < collateralsCount; ) {
            IOracle(collateralParams[collateralSupport[i]].oracle).fetchPrice();
            unchecked {
                i++;
            }
        }
    }

    function getValue(
        address[] memory _collaterals,
        uint256[] memory _amounts
    )
        public
        view
        override
        returns (uint256 totalValue, uint256[] memory values)
    {
        uint256 price = priceFeed.fetchPrice_view();
        return getValue(_collaterals, _amounts, price);
    }

    function getValue(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        uint256 _price
    )
        public
        view
        override
        returns (uint256 totalValue, uint256[] memory values)
    {
        uint256 collLen = _collaterals.length;
        require(collLen == _amounts.length, "Length mismatch");
        values = new uint256[](collLen);
        for (uint256 i = 0; i < collLen; ) {
            if (_amounts[i] != 0) {
                values[i] = _calcValue(_collaterals[i], _amounts[i], _price);
                totalValue = totalValue.add(values[i]);
            }

            unchecked {
                i++;
            }
        }
    }

    function _calcValue(
        address _collateral,
        uint256 _amount,
        uint256 _price
    ) internal view returns (uint256 value) {
        if (_collateral != wethAddress) {
            IOracle coll_adjust = IOracle(collateralParams[_collateral].oracle);
            uint256 valueRatio = collateralParams[_collateral].ratio;
            value = coll_adjust
                .fetchPrice_view()
                .mul(valueRatio)
                .div(DECIMAL_PRECISION)
                .mul(_amount)
                .div(DECIMAL_PRECISION)
                .mul(_price)
                .div(DECIMAL_PRECISION);
        } else {
            value = _amount.mul(_price).div(DECIMAL_PRECISION);
        }
    }

    function getTotalValue(
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) public view override returns (uint256 totalValue) {
        (totalValue, ) = getValue(
            _collaterals,
            _amounts,
            priceFeed.fetchPrice_view()
        );
    }

    function mintEToken(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        address _account,
        uint256 _price
    ) external override returns (uint256[] memory, uint256) {
        _requireCollIsBO();
        uint256 collLen = _collaterals.length;
        uint256[] memory shares = new uint256[](collLen);
        for (uint256 i = 0; i < collLen; ) {
            if (_amounts[i] != 0) {
                shares[i] = mint(_account, _collaterals[i], _amounts[i]);
            }

            unchecked {
                i++;
            }
        }
        if (_price != 0) {
            (uint256 value, ) = getValue(_collaterals, _amounts, _price);
            return (shares, value);
        } else {
            return (shares, 0);
        }
    }

    function applyRewards(
        address _borrower,
        uint256[] memory _pendingRewards
    ) external override returns (uint256[] memory) {
        _requireCollIsTM();
        uint256[] memory newShares = new uint256[](collateralsCount);
        for (uint256 i = 0; i < collateralsCount; ) {
            if (_pendingRewards[i] != 0) {
                mint(_borrower, collateralSupport[i], _pendingRewards[i]);
            }
            newShares[i] = IEToken(
                collateralParams[collateralSupport[i]].eToken
            ).sharesOf(_borrower);
            unchecked {
                i++;
            }
        }
        return newShares;
    }

    function burnEToken(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        address _account,
        uint256 _price
    ) external override returns (uint256[] memory, uint256) {
        _requireCollIsBO();
        uint256 collLen = _collaterals.length;
        uint256[] memory shares = new uint256[](collLen);
        for (uint256 i = 0; i < collLen; ) {
            if (_amounts[i] != 0) {
                shares[i] = burn(_account, _collaterals[i], _amounts[i]);
            }

            unchecked {
                i++;
            }
        }
        if (_price != 0) {
            (uint256 value, ) = getValue(_collaterals, _amounts, _price);
            return (shares, value);
        } else {
            return (shares, 0);
        }
    }

    function mint(
        address _account,
        address _collateral,
        uint256 _amount
    ) internal returns (uint256) {
        return
            IEToken(collateralParams[_collateral].eToken).mint(
                _account,
                _amount
            );
    }

    function burn(
        address _account,
        address _collateral,
        uint256 _amount
    ) internal returns (uint256) {
        return
            IEToken(collateralParams[_collateral].eToken).burn(
                _account,
                _amount
            );
    }

    function clearEToken(
        address _account,
        DataTypes.Status closedStatus
    ) external override returns (address[] memory) {
        _requireCollIsTM();
        if (closedStatus == DataTypes.Status.closedByOwner) {
            return collateralSupport;
        }
        for (uint256 i = 0; i < collateralsCount; ) {
            IEToken(collateralParams[collateralSupport[i]].eToken).clear(
                _account
            );
            unchecked {
                i++;
            }
        }
        return collateralSupport;
    }

    function resetEToken(
        address _account,
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) external override returns (uint256[] memory) {
        require(
            msg.sender == troveManagerRedemptionsAddress,
            "CollateralManager: Bad caller"
        );
        uint256 collLen = _collaterals.length;
        uint256[] memory shares = new uint256[](collLen);
        for (uint256 i = 0; i < collLen; ) {
            if (_amounts[i] != 0) {
                shares[i] = IEToken(collateralParams[_collaterals[i]].eToken)
                    .reset(_account, _amounts[i]);
            }

            unchecked {
                i++;
            }
        }
        return shares;
    }

    function getShares(
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) public view override returns (uint256[] memory) {
        uint256 collLen = _collaterals.length;
        uint256[] memory amounts = new uint256[](collLen);
        for (uint256 i = 0; i < collLen; ) {
            if (_amounts[i] != 0) {
                amounts[i] = IEToken(collateralParams[_collaterals[i]].eToken)
                    .getShare(_amounts[i]);
            }
            unchecked {
                i++;
            }
        }
        return amounts;
    }

    function getAmounts(
        address[] memory _collaterals,
        uint256[] memory _shares
    ) public view override returns (uint256[] memory) {
        uint256 collLen = _collaterals.length;
        uint256[] memory amounts = new uint256[](collLen);
        for (uint256 i = 0; i < collLen; ) {
            if (_shares[i] != 0) {
                amounts[i] = IEToken(collateralParams[_collaterals[i]].eToken)
                    .getAmount(_shares[i]);
            }
            unchecked {
                i++;
            }
        }
        return amounts;
    }

    function getTroveColls(
        address _borrower
    )
        public
        view
        override
        returns (uint256[] memory, uint256[] memory, address[] memory)
    {
        uint256[] memory amounts = new uint256[](collateralsCount);
        uint256[] memory shares = new uint256[](collateralsCount);
        for (uint256 i = 0; i < collateralsCount; ) {
            (amounts[i], shares[i]) = getTroveColl(
                _borrower,
                collateralSupport[i]
            );

            unchecked {
                i++;
            }
        }
        return (amounts, shares, collateralSupport);
    }

    function getTroveColl(
        address _borrower,
        address _collateral
    ) public view override returns (uint256, uint256) {
        uint256 amount = IEToken(collateralParams[_collateral].eToken)
            .balanceOf(_borrower);
        uint256 share = IEToken(collateralParams[_collateral].eToken).sharesOf(
            _borrower
        );

        return (amount, share);
    }

    function getCollateralShares(
        address _borrower
    ) external view override returns (address[] memory, uint256[] memory) {
        uint256[] memory shares = new uint256[](collateralsCount);
        for (uint256 i = 0; i < collateralsCount; ) {
            shares[i] = IEToken(collateralParams[collateralSupport[i]].eToken)
                .sharesOf(_borrower);
            unchecked {
                i++;
            }
        }
        return (collateralSupport, shares);
    }

    function getEntireCollValue()
        external
        view
        override
        returns (address[] memory, uint256[] memory, uint256)
    {
        uint256 price = priceFeed.fetchPrice_view();
        return getEntireCollValue(price);
    }

    function getEntireCollValue(
        uint256 _price
    )
        public
        view
        override
        returns (address[] memory, uint256[] memory, uint256)
    {
        uint256 totalValue;
        uint256[] memory amounts = new uint256[](collateralsCount);
        uint256 activeBalance;
        uint256 defautBalance;
        for (uint256 i = 0; i < collateralsCount; ) {
            activeBalance = IEToken(collateralParams[collateralSupport[i]].eToken).totalSupply();
            // activeBalance = IERC20Upgradeable(collateralSupport[i]).balanceOf(
            //     address(activePool)
            // );
            defautBalance = IERC20Upgradeable(collateralSupport[i]).balanceOf(
                address(defaultPool)
            );
            amounts[i] = activeBalance.add(defautBalance);
            totalValue = totalValue.add(
                _calcValue(collateralSupport[i], amounts[i], _price)
            );
            unchecked {
                i++;
            }
        }
        return (collateralSupport, amounts, totalValue);
    }

    function validAdjustment(
        address _account,
        address _collateral,
        uint256 _amount
    ) external view override returns (bool) {
        bool active = troveManager.getTroveStatus(_account) == 1;
        if (!active) {
            return true;
        }
        uint256 price = priceFeed.fetchPrice_view();
        uint256 totalDebt = getEntireSystemDebt();
        (, , uint256 totalValue) = getEntireSystemColl(price);
        bool isRecoveryMode = _checkRecoveryMode(totalValue, totalDebt, CCR);
        if (!isRecoveryMode) {
            return false;
        }
        (uint256[] memory colls, , ) = getTroveColls(_account);
        uint256 debt = troveManager.getTroveDebt(_account);
        (uint256 currValue, ) = getValue(collateralSupport, colls, price);
        uint256 value = _calcValue(_collateral, _amount, price);
        uint256 newICR = ERDMath._computeCR(currValue.sub(value), debt);
        if (newICR < MCR) {
            return false;
        }
        uint256 newTCR = ERDMath._computeCR(totalValue.sub(value), totalDebt);
        return newTCR >= CCR;
    }

    // --- Getters ---
    function getCollateralSupport()
        external
        view
        override
        returns (address[] memory)
    {
        return collateralSupport;
    }

    function getIsActive(
        address _collateral
    ) public view override returns (bool) {
        return (uint256(collateralParams[_collateral].status)) == 1;
    }

    function getIsSupport(
        address _collateral
    ) public view override returns (bool) {
        return (uint256(collateralParams[_collateral].status)) != 0;
    }

    function getCollateralOracle(
        address _collateral
    ) external view override returns (address) {
        return collateralParams[_collateral].oracle;
    }

    function getCollateralOracles()
        external
        view
        override
        returns (address[] memory)
    {
        address[] memory oracles = new address[](collateralsCount);
        for (uint256 i = 0; i < collateralsCount; ) {
            oracles[i] = collateralParams[collateralSupport[i]].oracle;
            unchecked {
                i++;
            }
        }
        return oracles;
    }

    function getCollateralParams(
        address _collateral
    ) external view override returns (DataTypes.CollateralParams memory) {
        return collateralParams[_collateral];
    }

    function getCollateralsAmount() external view override returns (uint256) {
        return collateralsCount;
    }

    function getIndex(
        address _collateral
    ) public view override returns (uint256) {
        require(
            getIsSupport(_collateral),
            "CollateralManager: Collateral not support"
        );
        return collateralParams[_collateral].index;
    }

    function getRatio(
        address _collateral
    ) external view override returns (uint256) {
        return collateralParams[_collateral].ratio;
    }

    // --- 'require' wrapper functions ---

    function _requireIsContract(address _contract) internal view {
        require(
            _contract.isContract(),
            "CollateralManager: Contract check error"
        );
    }

    function _requireRatioLegal(uint256 _ratio) internal pure {
        require(
            _ratio <= DECIMAL_PRECISION,
            "CollateralManager: Ratio must be less than 100%"
        );
    }

    function _requireCollIsActive(address _collateral) internal view {
        require(
            getIsActive(_collateral),
            "CollateralManager: Collateral not pause"
        );
    }

    function _requireCollIsBO() internal view {
        require(
            msg.sender == borrowerOperationsAddress,
            "CollateralManager: Bad caller"
        );
    }

    function _requireCollIsTM() internal view {
        require(
            msg.sender == address(troveManager),
            "CollateralManager: Bad caller"
        );
    }

    function adjustColls(
        uint256[] memory _initialAmounts,
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address[] memory _collsOut,
        uint256[] memory _amountsOut
    ) external view override returns (uint256[] memory newAmounts) {
        newAmounts = ERDMath._getArrayCopy(_initialAmounts);
        uint256 collsInLen = _collsIn.length;
        uint256 collsOutLen = _collsOut.length;
        for (uint256 i = 0; i < collsInLen; i++) {
            uint256 idx = getIndex(_collsIn[i]);
            newAmounts[idx] = newAmounts[idx].add(_amountsIn[i]);
        }

        for (uint256 i = 0; i < collsOutLen; i++) {
            uint256 idx = getIndex(_collsOut[i]);
            newAmounts[idx] = newAmounts[idx].sub(_amountsOut[i]);
        }
    }

    // --- Config update functions ---

    function setMCR(uint256 _mcr) external override onlyOwner {
        MCR = _mcr;
    }

    function setCCR(uint256 _ccr) external override onlyOwner {
        CCR = _ccr;
    }

    function setGasCompensation(uint256 _gas) external override onlyOwner {
        EUSD_GAS_COMPENSATION = _gas;
    }

    function setMinDebt(uint256 _minDebt) external override onlyOwner {
        MIN_NET_DEBT = _minDebt;
    }

    function setBorrowingFeeFloor(
        uint256 _borrowingFloor
    ) external override onlyOwner {
        BORROWING_FEE_FLOOR = _borrowingFloor;
    }

    function setRedemptionFeeFloor(
        uint256 _redemptionFloor
    ) external override onlyOwner {
        REDEMPTION_FEE_FLOOR = _redemptionFloor;
    }

    function setRecoveryFee(
        uint256 _redemptionFloor
    ) external override onlyOwner {
        RECOVERY_FEE = _redemptionFloor;
    }

    function setMaxBorrowingFee(
        uint256 _maxBorrowingFee
    ) external override onlyOwner {
        MAX_BORROWING_FEE = _maxBorrowingFee;
    }

    function setBootstrapPeriod(uint256 _period) external override onlyOwner {
        BOOTSTRAP_PERIOD = _period;
    }

    function setFactor(uint256 _factor) external override onlyOwner {
        troveManager.setFactor(_factor);
    }

    function getFactor() external view override returns (uint256) {
        return troveManager.getFactor();
    }

    function getCCR() external view override returns (uint256) {
        return CCR;
    }

    function getMCR() external view override returns (uint256) {
        return MCR;
    }

    function getEUSDGasCompensation() external view override returns (uint256) {
        return EUSD_GAS_COMPENSATION;
    }

    function getMinNetDebt() external view override returns (uint256) {
        return MIN_NET_DEBT;
    }

    function getMaxBorrowingFee() external view override returns (uint256) {
        return MAX_BORROWING_FEE;
    }

    function getBorrowingFeeFloor() external view override returns (uint256) {
        return BORROWING_FEE_FLOOR;
    }

    function getRedemptionFeeFloor() external view override returns (uint256) {
        return REDEMPTION_FEE_FLOOR;
    }

    function getRecoveryFee() external view override returns (uint256) {
        return RECOVERY_FEE;
    }

    function getBootstrapPeriod() external view override returns (uint256) {
        return BOOTSTRAP_PERIOD;
    }
}
