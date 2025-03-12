// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../oracle/IOracle.sol";
import '../lib/UniERC20.sol';
import "./IPikaPerp.sol";
import "./PikaPerpV3.sol";
import "../access/Governable.sol";
import "../referrals/IReferralStorage.sol";

contract OrderBook is Governable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using UniERC20 for IERC20;
    using Address for address payable;

    struct OpenOrder {
        address account;
        uint256 productId;
        uint256 margin;
        uint256 leverage;
        uint256 tradeFee;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
        uint256 orderTimestamp;
    }
    struct CloseOrder {
        address account;
        uint256 productId;
        uint256 size;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
        uint256 orderTimestamp;
    }

    mapping (address => mapping(uint256 => OpenOrder)) public openOrders;
    mapping (address => uint256) public openOrdersIndex;
    mapping (address => mapping(uint256 => CloseOrder)) public closeOrders;
    mapping (address => uint256) public closeOrdersIndex;
    mapping (address => bool) public isKeeper;
    mapping (address => bool) public managers;
    mapping (address => mapping (address => bool)) public approvedManagers;

    address public immutable pikaPerp;
    address public immutable collateralToken;
    uint256 public immutable tokenBase;
    address public admin;
    address public oracle;
    address public feeCalculator;
    address public referralStorage;
    uint256 public minExecutionFee;
    uint256 public minTimeCancelDelay;
    bool public allowPublicKeeper = false;
    uint256 public constant BASE = 1e8;
    uint256 public constant FEE_BASE = 1e4;

    event CreateOpenOrder(
        address indexed account,
        uint256 orderIndex,
        uint256 productId,
        uint256 margin,
        uint256 leverage,
        uint256 tradeFee,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 orderTimestamp
    );
    event CancelOpenOrder(
        address indexed account,
        uint256 orderIndex,
        uint256 productId,
        uint256 margin,
        uint256 leverage,
        uint256 tradeFee,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 orderTimestamp
    );
    event ExecuteOpenOrder(
        address indexed account,
        uint256 orderIndex,
        uint256 productId,
        uint256 margin,
        uint256 leverage,
        uint256 tradeFee,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 executionPrice,
        uint256 orderTimestamp,
        bytes32 referralCode,
        address referral
    );
    event UpdateOpenOrder(
        address indexed account,
        uint256 orderIndex,
        uint256 productId,
        uint256 margin,
        uint256 leverage,
        uint256 tradeFee,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 orderTimestamp
    );
    event CreateCloseOrder(
        address indexed account,
        uint256 orderIndex,
        uint256 productId,
        uint256 size,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 orderTimestamp
    );
    event CancelCloseOrder(
        address indexed account,
        uint256 orderIndex,
        uint256 productId,
        uint256 size,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 orderTimestamp
    );
    event ExecuteCloseOrder(
        address indexed account,
        uint256 orderIndex,
        uint256 productId,
        uint256 size,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 executionPrice,
        uint256 orderTimestamp,
        bytes32 referralCode,
        address referral
    );
    event UpdateCloseOrder(
        address indexed account,
        uint256 orderIndex,
        uint256 productId,
        uint256 size,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 orderTimestamp
    );
    event ExecuteOpenOrderError(address indexed account, uint256 orderIndex, string executionError);
    event ExecuteCloseOrderError(address indexed account, uint256 orderIndex, string executionError);
    event UpdateMinTimeExecuteDelay(uint256 minTimeExecuteDelay);
    event UpdateMinTimeCancelDelay(uint256 minTimeCancelDelay);
    event UpdateAllowPublicKeeper(bool allowPublicKeeper);
    event UpdateMinExecutionFee(uint256 minExecutionFee);
    event UpdateKeeper(address keeper, bool isAlive);
    event SetManager(address manager, bool isActive);
    event SetAccountManager(address account, address manager, bool isActive);
    event SetReferralStorage(address referralStorage);
    event UpdateAdmin(address admin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "OrderBook: !admin");
        _;
    }

    constructor(
        address _pikaPerp,
        address _oracle,
        address _collateralToken,
        uint256 _tokenBase,
        uint256 _minExecutionFee,
        address _feeCalculator
    ) public {
        admin = msg.sender;
        pikaPerp = _pikaPerp;
        oracle = _oracle;
        collateralToken = _collateralToken;
        tokenBase = _tokenBase;
        minExecutionFee = _minExecutionFee;
        feeCalculator = _feeCalculator;
    }

    function setOracle(address _oracle) external onlyAdmin {
        oracle = _oracle;
    }

    function setFeeCalculator(address _feeCalculator) external onlyAdmin {
        feeCalculator = _feeCalculator;
    }

    function setMinExecutionFee(uint256 _minExecutionFee) external onlyAdmin {
        minExecutionFee = _minExecutionFee;
        emit UpdateMinExecutionFee(_minExecutionFee);
    }

    function setMinTimeCancelDelay(uint256 _minTimeCancelDelay) external onlyAdmin {
        minTimeCancelDelay = _minTimeCancelDelay;
        emit UpdateMinTimeCancelDelay(_minTimeCancelDelay);
    }

    function setManager(address _manager, bool _isActive) external onlyAdmin {
        managers[_manager] = _isActive;
        emit SetManager(_manager, _isActive);
    }

    function setAccountManager(address _manager, bool _isActive) external {
        approvedManagers[msg.sender][_manager] = _isActive;
        emit SetAccountManager(msg.sender, _manager, _isActive);
    }

    function setReferralStorage(address _referralStorage) external onlyAdmin {
        referralStorage = _referralStorage;
        emit SetReferralStorage(_referralStorage);
    }

    function setAllowPublicKeeper(bool _allowPublicKeeper) external onlyAdmin {
        allowPublicKeeper = _allowPublicKeeper;
        emit UpdateAllowPublicKeeper(_allowPublicKeeper);
    }

    function setKeeper(address _account, bool _isActive) external onlyAdmin {
        isKeeper[_account] = _isActive;
        emit UpdateKeeper(_account, _isActive);
    }

    function setAdmin(address _admin) external onlyGov {
        admin = _admin;
        emit UpdateAdmin(_admin);
    }

    function executeOrdersWithPrices(
        bytes[] calldata _priceUpdateData,
        address[] memory _openAddresses,
        uint256[] memory _openOrderIndexes,
        address[] memory _closeAddresses,
        uint256[] memory _closeOrderIndexes,
        address payable _feeReceiver
    ) external {
        require(isKeeper[msg.sender] || allowPublicKeeper, "OrderBook: !keeper");
        IOracle(oracle).setPrices(_priceUpdateData);
        _executeOrders(_openAddresses, _openOrderIndexes, _closeAddresses, _closeOrderIndexes, _feeReceiver);
    }

    function _executeOrders(
        address[] memory _openAddresses,
        uint256[] memory _openOrderIndexes,
        address[] memory _closeAddresses,
        uint256[] memory _closeOrderIndexes,
        address payable _feeReceiver
    ) private {
        require(_openAddresses.length == _openOrderIndexes.length && _closeAddresses.length == _closeOrderIndexes.length, "OrderBook: not same length");
        for (uint256 i = 0; i < _openAddresses.length; i++) {
            try this.executeOpenOrder(_openAddresses[i], _openOrderIndexes[i], _feeReceiver) {
            } catch Error(string memory executionError) {
                emit ExecuteOpenOrderError(_openAddresses[i], _openOrderIndexes[i], executionError);
            } catch (bytes memory /*lowLevelData*/) {}
        }
        for (uint256 i = 0; i < _closeAddresses.length; i++) {
            try this.executeCloseOrder(_closeAddresses[i], _closeOrderIndexes[i], _feeReceiver) {
            } catch Error(string memory executionError) {
                emit ExecuteCloseOrderError(_closeAddresses[i], _closeOrderIndexes[i], executionError);
            } catch (bytes memory /*lowLevelData*/) {}
        }
    }

    function cancelMultiple(
        uint256[] memory _openOrderIndexes,
        uint256[] memory _closeOrderIndexes
    ) external {
        for (uint256 i = 0; i < _openOrderIndexes.length; i++) {
            cancelOpenOrder(_openOrderIndexes[i]);
        }
        for (uint256 i = 0; i < _closeOrderIndexes.length; i++) {
            cancelCloseOrder(msg.sender, _closeOrderIndexes[i]);
        }
    }

    function cancelMultipleCloseOrder(
        address[] memory _closeOrderAccounts,
        uint256[] memory _closeOrderIndexes
    ) external {
        for (uint256 i = 0; i < _closeOrderIndexes.length; i++) {
            cancelCloseOrder(_closeOrderAccounts[i], _closeOrderIndexes[i]);
        }
    }

    function validatePositionOrderPrice(
        bool _isLong,
        bool _triggerAboveThreshold,
        uint256 _triggerPrice,
        uint256 _productId
    ) public view returns (uint256, bool) {
        (address productToken,,,,,,,,) = IPikaPerp(pikaPerp).getProduct(_productId);
        uint256 currentPrice = _isLong ? IOracle(oracle).getPrice(productToken, true) : IOracle(oracle).getPrice(productToken, false);
        bool isPriceValid = _triggerAboveThreshold ? currentPrice >= _triggerPrice : currentPrice <= _triggerPrice;
        require(isPriceValid, "OrderBook: invalid price for execution");
        return (currentPrice, isPriceValid);
    }

    function getCloseOrder(address _account, uint256 _orderIndex) public view returns (
        uint256 productId,
        uint256 size,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 orderTimestamp
    ) {
        CloseOrder memory order = closeOrders[_account][_orderIndex];
        return (
        order.productId,
        order.size,
        order.isLong,
        order.triggerPrice,
        order.triggerAboveThreshold,
        order.executionFee,
        order.orderTimestamp
        );
    }

    function getOpenOrder(address _account, uint256 _orderIndex) public view returns (
        uint256 productId,
        uint256 margin,
        uint256 leverage,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 orderTimestamp
    ) {
        OpenOrder memory order = openOrders[_account][_orderIndex];
        return (
        order.productId,
        order.margin,
        order.leverage,
        order.isLong,
        order.triggerPrice,
        order.triggerAboveThreshold,
        order.executionFee,
        order.orderTimestamp
        );
    }

    function createOpenOrder(
        address _account,
        uint256 _productId,
        uint256 _margin,
        uint256 _leverage,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold,
        uint256 _executionFee
    ) external payable nonReentrant {
        require(_executionFee >= minExecutionFee, "OrderBook: insufficient execution fee");
        require(msg.sender == _account || _validateManager(_account), "PositionManager: no permission for account");
        uint256 tradeFee = _getTradeFeeRate(_productId, _account) * _margin * _leverage / (FEE_BASE * BASE);
        if (IERC20(collateralToken).isETH()) {
            IERC20(collateralToken).uniTransferFromSenderToThis((_executionFee + _margin + tradeFee) * tokenBase / BASE);
        } else {
            require(msg.value == _executionFee * 1e18 / BASE, "OrderBook: incorrect execution fee transferred");
            IERC20(collateralToken).uniTransferFromSenderToThis((_margin + tradeFee) * tokenBase / BASE);
        }

        _createOpenOrder(
            _account,
            _productId,
            _margin,
            tradeFee,
            _leverage,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee
        );
    }

    function _createOpenOrder(
        address _account,
        uint256 _productId,
        uint256 _margin,
        uint256 _tradeFee,
        uint256 _leverage,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold,
        uint256 _executionFee
    ) private {
        uint256 _orderIndex = openOrdersIndex[_account];
        OpenOrder memory order = OpenOrder(
            _account,
            _productId,
            _margin,
            _leverage,
            _tradeFee,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee,
            block.timestamp
        );
        openOrdersIndex[_account] = _orderIndex.add(1);
        openOrders[_account][_orderIndex] = order;
        emit CreateOpenOrder(
            _account,
            _orderIndex,
            _productId,
            _margin,
            _leverage,
            _tradeFee,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee,
            block.timestamp
        );
    }

    function updateOpenOrder(
        uint256 _orderIndex,
        uint256 _leverage,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external nonReentrant {
        OpenOrder storage order = openOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        if (order.leverage != _leverage) {
            uint256 margin = (order.margin + order.tradeFee) * BASE / (BASE + _getTradeFeeRate(order.productId, order.account) * _leverage / 10**4);
            uint256 tradeFee = order.tradeFee + order.margin - margin;
            order.margin = margin;
            order.tradeFee = tradeFee;
            order.leverage = _leverage;
        }
        order.triggerPrice = _triggerPrice;
        order.triggerAboveThreshold = _triggerAboveThreshold;
        order.orderTimestamp = block.timestamp;

        emit UpdateOpenOrder(
            msg.sender,
            _orderIndex,
            order.productId,
            order.margin,
            order.leverage,
            order.tradeFee,
            order.isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            block.timestamp
        );
    }

    function cancelOpenOrder(uint256 _orderIndex) public nonReentrant {
        OpenOrder memory order = openOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        require(order.orderTimestamp + minTimeCancelDelay < block.timestamp, "OrderBook: min time cancel delay not yet passed");

        delete openOrders[msg.sender][_orderIndex];

        if (IERC20(collateralToken).isETH()) {
            IERC20(collateralToken).uniTransfer(msg.sender, (order.executionFee + order.margin + order.tradeFee) * tokenBase / BASE);
        } else {
            IERC20(collateralToken).uniTransfer(msg.sender, (order.margin + order.tradeFee) * tokenBase / BASE);
            payable(msg.sender).sendValue(order.executionFee * 1e18 / BASE);
        }

        emit CancelOpenOrder(
            order.account,
            _orderIndex,
            order.productId,
            order.margin,
            order.tradeFee,
            order.leverage,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee,
            order.orderTimestamp
        );
    }

    function executeOpenOrder(address _address, uint256 _orderIndex, address payable _feeReceiver) public nonReentrant {
        OpenOrder memory order = openOrders[_address][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        require(msg.sender == address(this), "OrderBook: not calling from this contract");
        (uint256 currentPrice, ) = validatePositionOrderPrice(
            order.isLong,
            order.triggerAboveThreshold,
            order.triggerPrice,
            order.productId
        );

        delete openOrders[_address][_orderIndex];

        if (IERC20(collateralToken).isETH()) {
            IPikaPerp(pikaPerp).openPosition{value: (order.margin + order.tradeFee) * tokenBase / BASE }(_address, order.productId, order.margin, order.isLong, order.leverage);
        } else {
            IERC20(collateralToken).safeApprove(pikaPerp, 0);
            IERC20(collateralToken).safeApprove(pikaPerp, (order.margin + order.tradeFee) * tokenBase / BASE);
            IPikaPerp(pikaPerp).openPosition(_address, order.productId, order.margin, order.isLong, order.leverage);
        }

        // pay executor
        _feeReceiver.sendValue(order.executionFee * 1e18 / BASE);

        if (referralStorage == address(0)) {
            return;
        }
        (bytes32 referralCode, address referrer) = IReferralStorage(referralStorage).getTraderReferralInfo(order.account);

        emit ExecuteOpenOrder(
            order.account,
            _orderIndex,
            order.productId,
            order.margin,
            order.leverage,
            order.tradeFee,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee,
            currentPrice,
            order.orderTimestamp,
            referralCode,
            referrer
        );
    }

    function createCloseOrder(
        address _account,
        uint256 _productId,
        uint256 _size,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable nonReentrant {
        require(msg.value >= minExecutionFee * 1e18 / BASE, "OrderBook: insufficient execution fee");
        require(msg.sender == _account || _validateManager(_account), "PositionManager: no permission for account");
        _createCloseOrder(
            _account,
            _productId,
            _size,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold
        );
    }

    function _createCloseOrder(
        address _account,
        uint256 _productId,
        uint256 _size,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) private {
        uint256 _orderIndex = closeOrdersIndex[_account];
        CloseOrder memory order = CloseOrder(
            _account,
            _productId,
            _size,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            msg.value * BASE / 1e18,
            block.timestamp
        );
        closeOrdersIndex[_account] = _orderIndex.add(1);
        closeOrders[_account][_orderIndex] = order;

        emit CreateCloseOrder(
            _account,
            _orderIndex,
            _productId,
            _size,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            msg.value,
            block.timestamp
        );
    }

    function executeCloseOrder(address _address, uint256 _orderIndex, address payable _feeReceiver) public nonReentrant {
        CloseOrder memory order = closeOrders[_address][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        require(msg.sender == address(this), "OrderBook: not calling from this contract");
        (,uint256 leverage,,,,,,,) = IPikaPerp(pikaPerp).getPosition(_address, order.productId, order.isLong);
        (uint256 currentPrice, ) = validatePositionOrderPrice(
            !order.isLong,
            order.triggerAboveThreshold,
            order.triggerPrice,
            order.productId
        );

        delete closeOrders[_address][_orderIndex];
        IPikaPerp(pikaPerp).closePosition(_address, order.productId, order.size * BASE / leverage , order.isLong);

        // pay executor
        _feeReceiver.sendValue(order.executionFee * 1e18 / BASE);

        if (referralStorage == address(0)) {
            return;
        }
        (bytes32 referralCode, address referrer) = IReferralStorage(referralStorage).getTraderReferralInfo(order.account);

        emit ExecuteCloseOrder(
            order.account,
            _orderIndex,
            order.productId,
            order.size,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee,
            currentPrice,
            order.orderTimestamp,
            referralCode,
            referrer
        );
    }

    function cancelCloseOrder(address _account, uint256 _orderIndex) public nonReentrant {
        CloseOrder memory order = closeOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        // close order can be cancelled by the order owner anytime, or by anyone if there's no active position for the order owner
        require(msg.sender == _account || !_validatePosition(_account, order.productId, order.isLong), "PositionManager: no permission for account");
        require(order.orderTimestamp + minTimeCancelDelay < block.timestamp, "OrderBook: min time cancel delay not yet passed");

        delete closeOrders[_account][_orderIndex];

        payable(_account).sendValue(order.executionFee * 1e18 / BASE);

        emit CancelCloseOrder(
            order.account,
            _orderIndex,
            order.productId,
            order.size,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee,
            order.orderTimestamp
        );
    }

    function updateCloseOrder(
        uint256 _orderIndex,
        uint256 _size,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external nonReentrant {
        CloseOrder storage order = closeOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        order.size = _size;
        order.triggerPrice = _triggerPrice;
        order.triggerAboveThreshold = _triggerAboveThreshold;
        order.orderTimestamp = block.timestamp;

        emit UpdateCloseOrder(
            msg.sender,
            _orderIndex,
            order.productId,
            _size,
            order.isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            block.timestamp
        );
    }

    function _getTradeFeeRate(uint256 _productId, address _account) private returns(uint256) {
        (address productToken,,uint256 fee,,,,,,) = IPikaPerp(pikaPerp).getProduct(_productId);
        return IFeeCalculator(feeCalculator).getFee(productToken, fee, _account, msg.sender);
    }

    function _validateManager(address account) private view returns(bool) {
        return managers[msg.sender] && approvedManagers[account][msg.sender];
    }

    function _validatePosition(address _account, uint256 _productId, bool _isLong) private view returns(bool) {
        (uint256 productId,,,,,,,,) = IPikaPerp(pikaPerp).getPosition(_account, _productId, _isLong);
        return productId > 0;
    }

    fallback() external payable {}
    receive() external payable {}
}
