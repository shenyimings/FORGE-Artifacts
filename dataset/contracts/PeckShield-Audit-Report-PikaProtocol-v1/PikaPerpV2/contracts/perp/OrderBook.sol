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

    address public immutable pikaPerp;
    address public immutable collateralToken;
    uint256 public immutable tokenBase;
    address public admin;
    address public oracle;
    address public feeCalculator;
    uint256 public minExecutionFee;
    uint256 public minTimeExecuteDelay;
    uint256 public minTimeCancelDelay;
    bool public allowPublicKeeper = false;
    bool public isKeeperCall = false;
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
        uint256 orderTimestamp
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
        uint256 orderTimestamp
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
    event UpdateAdmin(address admin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "OrderBook: !admin");
        _;
    }

    modifier onlyKeeper() {
        require(isKeeper[msg.sender], "OrderBook: !keeper");
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

    function setMinTimeExecuteDelay(uint256 _minTimeExecuteDelay) external onlyAdmin {
        minTimeExecuteDelay = _minTimeExecuteDelay;
        emit UpdateMinTimeExecuteDelay(_minTimeExecuteDelay);
    }

    function setMinTimeCancelDelay(uint256 _minTimeCancelDelay) external onlyAdmin {
        minTimeCancelDelay = _minTimeCancelDelay;
        emit UpdateMinTimeCancelDelay(_minTimeCancelDelay);
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
        address[] memory tokens,
        uint256[] memory prices,
        address[] memory _openAddresses,
        uint256[] memory _openOrderIndexes,
        address[] memory _closeAddresses,
        uint256[] memory _closeOrderIndexes,
        address payable _feeReceiver
    ) external onlyKeeper {
        IOracle(oracle).setPrices(tokens, prices);
        executeOrders(_openAddresses, _openOrderIndexes, _closeAddresses, _closeOrderIndexes, _feeReceiver);
    }

    function executeOrders(
        address[] memory _openAddresses,
        uint256[] memory _openOrderIndexes,
        address[] memory _closeAddresses,
        uint256[] memory _closeOrderIndexes,
        address payable _feeReceiver
    ) public {
        require(_openAddresses.length == _openOrderIndexes.length && _closeAddresses.length == _closeOrderIndexes.length, "OrderBook: not same length");
        isKeeperCall = isKeeper[msg.sender];
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
        isKeeperCall = false;
    }

    function cancelMultiple(
        uint256[] memory _openOrderIndexes,
        uint256[] memory _closeOrderIndexes
    ) external {
        for (uint256 i = 0; i < _openOrderIndexes.length; i++) {
            cancelOpenOrder(_openOrderIndexes[i]);
        }
        for (uint256 i = 0; i < _closeOrderIndexes.length; i++) {
            cancelCloseOrder(_closeOrderIndexes[i]);
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
        uint256 _productId,
        uint256 _margin,
        uint256 _leverage,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold,
        uint256 _executionFee
    ) external payable nonReentrant {
        require(_executionFee >= minExecutionFee, "OrderBook: insufficient execution fee");

        uint256 tradeFee = getTradeFeeRate(_productId, msg.sender) * _margin * _leverage / (FEE_BASE * BASE);
        if (IERC20(collateralToken).isETH()) {
            IERC20(collateralToken).uniTransferFromSenderToThis((_executionFee + _margin + tradeFee) * tokenBase / BASE);
        } else {
            require(msg.value == _executionFee * 1e18 / BASE, "OrderBook: incorrect execution fee transferred");
            IERC20(collateralToken).uniTransferFromSenderToThis((_margin + tradeFee) * tokenBase / BASE);
        }

        _createOpenOrder(
            msg.sender,
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
        uint256 _orderIndex = openOrdersIndex[msg.sender];
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
            uint256 margin = (order.margin + order.tradeFee) * BASE / (BASE + getTradeFeeRate(order.productId, order.account) * _leverage / 10**4);
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
        require((msg.sender == address(this) && isKeeperCall) || isKeeper[msg.sender] || (allowPublicKeeper && order.orderTimestamp + minTimeExecuteDelay < block.timestamp),
            "OrderBook: min time execute delay not yet passed");
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
            order.orderTimestamp
        );
    }

    function createCloseOrder(
        uint256 _productId,
        uint256 _size,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable nonReentrant {
        require(msg.value >= minExecutionFee * 1e18 / BASE, "OrderBook: insufficient execution fee");

        _createCloseOrder(
            msg.sender,
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
        require((msg.sender == address(this) && isKeeperCall) || isKeeper[msg.sender] || (allowPublicKeeper && order.orderTimestamp + minTimeExecuteDelay < block.timestamp),
            "OrderBook: min time execute delay not yet passed");
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
            order.orderTimestamp
        );
    }

    function cancelCloseOrder(uint256 _orderIndex) public nonReentrant {
        CloseOrder memory order = closeOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        require(order.orderTimestamp + minTimeCancelDelay < block.timestamp, "OrderBook: min time cancel delay not yet passed");

        delete closeOrders[msg.sender][_orderIndex];

        payable(msg.sender).sendValue(order.executionFee * 1e18 / BASE);

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

    function getTradeFeeRate(uint256 _productId, address _account) private returns(uint256) {
        (address productToken,,uint256 fee,,,,,,) = IPikaPerp(pikaPerp).getProduct(_productId);
        return IFeeCalculator(feeCalculator).getFee(productToken, fee, _account, msg.sender);
    }

    fallback() external payable {}
    receive() external payable {}
}
