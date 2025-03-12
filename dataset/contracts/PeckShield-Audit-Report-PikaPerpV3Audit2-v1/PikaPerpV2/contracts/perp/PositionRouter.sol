pragma solidity ^0.8.0;

import "./IPositionManager.sol";
import "./IOrderBook.sol";
import "../access/Governable.sol";

contract PositionRouter {

    address public positionManager;
    address public orderbook;
    uint256 public constant BASE = 1e8;

    constructor(
        address _positionManager,
        address _orderbook
    ) public {
        positionManager = _positionManager;
        orderbook = _orderbook;
    }

    function createOpenMarketOrderWithTriggerOrders (
        uint256 _productId,
        uint256 _margin,
        uint256 _leverage,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee,
        uint256 _stopLossPrice,
        uint256 _takeProfitPrice,
        bytes32 _referralCode
    ) external {
        IPositionManager(positionManager).createOpenPosition(
            msg.sender,
            _productId,
            _margin,
            _leverage,
            _isLong,
            _acceptablePrice,
            _executionFee,
            _referralCode
        );
        if (_stopLossPrice != 0) {
            IOrderBook(orderbook).createCloseOrder(
                msg.sender,
                _productId,
                _margin * _leverage / BASE,
                _isLong,
                _stopLossPrice,
                _isLong ? false : true
            );
        }
        if (_takeProfitPrice != 0) {
            IOrderBook(orderbook).createCloseOrder(
                msg.sender,
                _productId,
                _margin * _leverage / BASE,
                _isLong,
                _takeProfitPrice,
                _isLong ? true : false
            );
        }
    }
}
