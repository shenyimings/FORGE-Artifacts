// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "./interfaces/DexAggregatorInterface.sol";
import "./interfaces/OpenLevInterface.sol";
import "./IOPLimitOrder.sol";
import "./IOPLimitOrder.sol";

abstract contract OPLimitOrderStorage {
    event OrderCanceled(address indexed trader, bytes32 orderId, uint256 remaining);

    event OrderFilled(address indexed trader, bytes32 orderId, uint256 commission, uint256 remaining, uint256 filling);

    struct Order {
        uint256 salt;
        address owner;
        uint32 deadline;
        uint16 marketId;
        bool longToken;
        bool depositToken;
        address commissionToken;
        uint256 commission;
        uint256 price0; // tokanA-tokenB pair, the price of tokenA relative to tokenB, scale 10**18.
    }

    struct OpenOrder {
        uint256 salt;
        address owner;
        uint32 deadline; // in seconds
        uint16 marketId;
        bool longToken;
        bool depositToken;
        address commissionToken;
        uint256 commission;
        uint256 price0;
        uint256 deposit; // the deposit amount for margin trade.
        uint256 borrow; // the borrow amount for margin trade.
        uint256 expectHeld; // the minimum position held after the order gets fully filled.
    }

    struct CloseOrder {
        uint256 salt;
        address owner;
        uint32 deadline;
        uint16 marketId;
        bool longToken;
        bool depositToken;
        address commissionToken;
        uint256 commission;
        uint256 price0;
        bool isStopLoss; // true = stopLoss, false = takeProfit.
        uint256 closeHeld; // how many position will be closed.
        uint256 expectReturn; // the minimum deposit returns after gets filled.
    }

    bytes32 public constant ORDER_TYPEHASH =
        keccak256(
            "Order(uint256 salt,address owner,uint32 deadline,uint16 marketId,bool longToken,bool depositToken,address commissionToken,uint256 commission,uint256 price0)"
        );
    bytes32 public constant OPEN_ORDER_TYPEHASH =
        keccak256(
            "OpenOrder(uint256 salt,address owner,uint32 deadline,uint16 marketId,bool longToken,bool depositToken,address commissionToken,uint256 commission,uint256 price0,uint256 deposit,uint256 borrow,uint256 expectHeld)"
        );
    bytes32 public constant CLOSE_ORDER_TYPEHASH =
        keccak256(
            "CloseOrder(uint256 salt,address owner,uint32 deadline,uint16 marketId,bool longToken,bool depositToken,address commissionToken,uint256 commission,uint256 price0,bool isStopLoss,uint256 closeHeld,uint256 expectReturn)"
        );

    OpenLevInterface public openLev;
    DexAggregatorInterface public dexAgg;
}

interface IOPLimitOrder {
    function fillOpenOrder(
        OPLimitOrderStorage.OpenOrder memory order,
        bytes calldata signature,
        uint256 fillingDeposit,
        bytes memory dexData
    ) external;

    function fillCloseOrder(
        OPLimitOrderStorage.CloseOrder memory order,
        bytes calldata signature,
        uint256 fillingHeld,
        bytes memory dexData
    ) external;

    function closeTradeAndCancel(
        uint16 marketId,
        bool longToken,
        uint256 closeHeld,
        uint256 minOrMaxAmount,
        bytes memory dexData,
        OPLimitOrderStorage.Order[] memory orders
    ) external;

    function cancelOrder(OPLimitOrderStorage.Order memory order) external;

    function cancelOrders(OPLimitOrderStorage.Order[] calldata orders) external;

    function remaining(bytes32 _orderId) external view returns (uint256);

    function remainingRaw(bytes32 _orderId) external view returns (uint256);

    function getOrderId(OPLimitOrderStorage.Order memory order) external view returns (bytes32);

    function hashOpenOrder(OPLimitOrderStorage.OpenOrder memory order) external view returns (bytes32);

    function hashCloseOrder(OPLimitOrderStorage.CloseOrder memory order) external view returns (bytes32);
}
