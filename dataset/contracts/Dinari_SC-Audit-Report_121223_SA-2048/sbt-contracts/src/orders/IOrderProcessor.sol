// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

/// @notice Interface for contracts processing orders for bridged assets
/// @author Dinari (https://github.com/dinaricrypto/sbt-contracts/blob/main/src/orders/IOrderProcessor.sol)
/// This interface provides a standard Order type and order lifecycle events
/// Orders are requested on-chain, processed off-chain, then fulfillment is submitted for on-chain settlement
/// Processor operators have a consistent interface for processing orders and submitting fulfillment
interface IOrderProcessor {
    /// ------------------ Types ------------------ ///

    // Market or limit order
    enum OrderType {
        MARKET,
        LIMIT
    }

    // Time in force
    enum TIF
    // Good until end of day
    {
        DAY,
        // Good until cancelled
        GTC,
        // Immediate or cancel
        IOC,
        // Fill or kill
        FOK
    }

    // Order status enum
    enum OrderStatus
    // Order is active
    {
        ACTIVE,
        // Order is completely filled
        FULFILLED,
        // Order is cancelled
        CANCELLED
    }

    // Emitted order data for off-chain order fulfillment
    struct Order {
        // Recipient of order fills
        address recipient;
        // Bridged asset token
        address assetToken;
        // Payment token
        address paymentToken;
        // Buy or sell
        bool sell;
        // Market or limit
        OrderType orderType;
        // Amount of asset token to be used for fills
        uint256 assetTokenQuantity;
        // Amount of payment token to be used for fills
        uint256 paymentTokenQuantity;
        // Price for limit orders
        uint256 price;
        // Time in force
        TIF tif;
    }

    /// @dev Fully specifies order details and index used to generate order ID
    event OrderRequested(address indexed recipient, uint256 indexed index, Order order);
    /// @dev Emitted for each fill
    event OrderFill(
        address indexed recipient, uint256 indexed index, uint256 fillAmount, uint256 receivedAmount, uint256 feesPaid
    );
    /// @dev Emitted when order is completely filled, terminal
    event OrderFulfilled(address indexed recipient, uint256 indexed index);
    /// @dev Emitted when order cancellation is requested
    event CancelRequested(address indexed recipient, uint256 indexed index);
    /// @dev Emitted when order is cancelled, terminal
    event OrderCancelled(address indexed recipient, uint256 indexed index, string reason);

    /// ------------------ Getters ------------------ ///

    /// @notice Total number of open orders
    function numOpenOrders() external view returns (uint256);

    /// @notice Next order index to use for onchain enumeration of orders per recipient
    /// @param recipient Recipient of order fills
    function nextOrderIndex(address recipient) external view returns (uint256);

    /// @notice Get order ID from order recipient and index
    /// @param recipient Recipient of order fills
    /// @param index Recipient order index
    /// @dev Order ID is used as key to store order state
    function getOrderId(address recipient, uint256 index) external pure returns (bytes32);

    /// @notice Status of a given order
    /// @param id Order ID
    function getOrderStatus(bytes32 id) external view returns (OrderStatus);

    /// @notice Get remaining order quantity to fill
    /// @param id Order ID
    function getUnfilledAmount(bytes32 id) external view returns (uint256);

    /// @notice Get total received for order
    /// @param id Order ID
    function getTotalReceived(bytes32 id) external view returns (uint256);

    /// @notice This function fetches the total balance held in escrow for a given user and token
    /// @param token The address of the token for which the escrowed balance is fetched
    /// @param user The address of the user for which the escrowed balance is fetched
    /// @return Returns the total amount of the specific token held in escrow for the given user
    function escrowedBalanceOf(address token, address user) external view returns (uint256);

    /// @notice This function retrieves the number of decimal places configured for a given token
    /// @param token The address of the token for which the number of decimal places is fetched
    /// @return Returns the number of decimal places set for the specified token
    function maxOrderDecimals(address token) external view returns (uint256);

    /// @notice Get fee rates for an order
    /// @param requester Requester of order
    /// @param sell Sell order
    /// @param token Payment token for order
    /// @return flatFee Flat fee for order
    /// @return percentageFeeRate Percentage fee rate for order
    function getFeeRatesForOrder(address requester, bool sell, address token) external view returns (uint256, uint24);

    /// @notice Get total fees for an order
    /// @param requester Requester of order
    /// @param sell Sell order
    /// @param paymentToken Payment token for order
    /// @param paymentTokenOrderValue Order payment token quantity
    function estimateTotalFeesForOrder(
        address requester,
        bool sell,
        address paymentToken,
        uint256 paymentTokenOrderValue
    ) external view returns (uint256);

    /// @dev Returns `true` if `account` has been granted `role`.
    function hasRole(bytes32 role, address account) external view returns (bool);

    function FORWARDER_ROLE() external view returns (bytes32);

    /// ------------------ Actions ------------------ ///

    /// @notice Request an order
    /// @param order Order request to submit
    /// @dev Emits OrderRequested event to be sent to fulfillment service (operator)
    function requestOrder(Order calldata order) external returns (uint256);

    /// @notice Fill an order
    /// @param order Order request to fill
    /// @param index order index
    /// @param fillAmount Amount of order token to fill
    /// @param receivedAmount Amount of received token
    /// @dev Only callable by operator
    function fillOrder(Order calldata order, uint256 index, uint256 fillAmount, uint256 receivedAmount) external;

    /// @notice Request to cancel an order
    /// @param recipient Recipient of order fills
    /// @param index Order index
    /// @dev Only callable by initial order requester
    /// @dev Emits CancelRequested event to be sent to fulfillment service (operator)
    function requestCancel(address recipient, uint256 index) external;

    /// @notice Cancel an order
    /// @param order Order request to cancel
    /// @param order index
    /// @param reason Reason for cancellation
    /// @dev Only callable by operator
    function cancelOrder(Order calldata order, uint256 index, string calldata reason) external;
}
