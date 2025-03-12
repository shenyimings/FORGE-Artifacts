// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {OrderProcessor} from "./OrderProcessor.sol";
import {BuyProcessor, ITokenLockCheck} from "./BuyProcessor.sol";

/// @notice Contract managing market purchase orders for bridged assets with direct payment
/// @author Dinari (https://github.com/dinaricrypto/sbt-contracts/blob/main/src/orders/BuyUnlockedProcessor.sol)
/// This order processor emits market orders to buy the underlying asset that are good until cancelled
/// Fees are calculated upfront and held back from the order amount
/// The payment is taken by the operator before the order is filled
/// The operator can return unused payment to the user
/// The operator cannot cancel the order until payment is returned or the order is filled
/// Implicitly assumes that asset tokens are dShare and can be minted
/// Order lifecycle (fulfillment):
///   1. User requests an order (requestOrder)
///   2. Operator takes escrowed payment (takeEscrow)
///   3. [Optional] Operator partially fills the order (fillOrder)
///   4. Operator completely fulfills the order (fillOrder)
/// Order lifecycle (cancellation):
///   1. User requests an order (requestOrder)
///   2. Operator takes escrowed payment (takeEscrow)
///   3. [Optional] Operator partially fills the order (fillOrder)
///   4. [Optional] User requests cancellation (requestCancel)
///   5. Operator returns unused payment to contract (returnEscrow)
///   6. Operator cancels the order (cancelOrder)
contract BuyUnlockedProcessor is BuyProcessor {
    using SafeERC20 for IERC20;

    /// ------------------ Types ------------------ ///

    /// @dev Escrowed payment has been taken
    error UnreturnedEscrow();

    /// @dev Emitted when `amount` of escrowed payment is taken for order
    event EscrowTaken(address indexed recipient, uint256 indexed index, uint256 amount);
    /// @dev Emitted when `amount` of escrowed payment is returned for order
    event EscrowReturned(address indexed recipient, uint256 indexed index, uint256 amount);

    /// ------------------ State ------------------ ///

    /// @dev orderId => escrow
    mapping(bytes32 => uint256) public getOrderEscrow;

    constructor(
        address _owner,
        address _treasury,
        uint64 _perOrderFee,
        uint24 _percentageFeeRate,
        ITokenLockCheck _tokenLockCheck
    ) BuyProcessor(_owner, _treasury, _perOrderFee, _percentageFeeRate, _tokenLockCheck) {}

    /// ------------------ Order Lifecycle ------------------ ///

    /// @notice Take escrowed payment for an order
    /// @param order Order
    /// @param index order index
    /// @param amount Amount of escrowed payment token to take
    /// @dev Only callable by operator
    function takeEscrow(Order calldata order, uint256 index, uint256 amount) external onlyRole(OPERATOR_ROLE) {
        // No nonsense
        if (amount == 0) revert ZeroValue();
        bytes32 id = getOrderId(order.recipient, index);
        // Verify order data
        bytes32 orderHash = _getOrderHash(id);
        if (orderHash != hashOrderCalldata(order)) revert InvalidOrderData();
        // Can't take more than escrowed
        uint256 escrow = getOrderEscrow[id];
        if (amount > escrow) revert AmountTooLarge();

        // Update escrow tracking
        getOrderEscrow[id] = escrow - amount;
        escrowedBalanceOf[order.paymentToken][order.recipient] -= amount;
        // Notify escrow taken
        emit EscrowTaken(order.recipient, index, amount);

        // Take escrowed payment
        IERC20(order.paymentToken).safeTransfer(msg.sender, amount);
    }

    /// @notice Return unused escrowed payment for an order
    /// @param order Order
    /// @param index order index
    /// @param amount Amount of payment token to return to escrow
    /// @dev Only callable by operator
    function returnEscrow(Order calldata order, uint256 index, uint256 amount) external onlyRole(OPERATOR_ROLE) {
        // No nonsense
        if (amount == 0) revert ZeroValue();
        bytes32 id = getOrderId(order.recipient, index);
        // Verify order data
        bytes32 orderHash = _getOrderHash(id);
        if (orderHash != hashOrderCalldata(order)) revert InvalidOrderData();
        // Can only return unused amount
        uint256 unfilledAmount = getUnfilledAmount(id);
        uint256 escrow = getOrderEscrow[id];
        // Unused amount = remaining order - remaining escrow
        if (escrow + amount > unfilledAmount) revert AmountTooLarge();

        // Update escrow tracking
        getOrderEscrow[id] = escrow + amount;
        escrowedBalanceOf[order.paymentToken][order.recipient] += amount;
        // Notify escrow returned
        emit EscrowReturned(order.recipient, index, amount);

        // Return payment to escrow
        IERC20(order.paymentToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc OrderProcessor
    function _requestOrderAccounting(bytes32 id, Order calldata order, uint256 totalFees) internal virtual override {
        // Compile standard buy order
        super._requestOrderAccounting(id, order, totalFees);
        // Initialize escrow tracking for order
        getOrderEscrow[id] = order.paymentTokenQuantity;
    }

    /// @inheritdoc OrderProcessor
    function _fillOrderAccounting(
        bytes32 id,
        Order calldata order,
        OrderState memory orderState,
        uint256 unfilledAmount,
        uint256 fillAmount,
        uint256 receivedAmount
    ) internal virtual override returns (uint256 paymentEarned, uint256 feesEarned) {
        // Can't fill more than payment previously taken from escrow
        uint256 escrow = getOrderEscrow[id];
        if (fillAmount > unfilledAmount - escrow) revert AmountTooLarge();

        paymentEarned = 0;
        (, feesEarned) = super._fillOrderAccounting(id, order, orderState, unfilledAmount, fillAmount, receivedAmount);
    }

    /// @inheritdoc OrderProcessor
    function _cancelOrderAccounting(
        bytes32 id,
        Order calldata order,
        OrderState memory orderState,
        uint256 unfilledAmount
    ) internal virtual override returns (uint256 refund) {
        // Prohibit cancel if escrowed payment has been taken and not returned or filled
        uint256 escrow = getOrderEscrow[id];
        if (unfilledAmount != escrow) revert UnreturnedEscrow();

        // Clear the escrow record
        delete getOrderEscrow[id];

        // Standard buy order accounting
        refund = super._cancelOrderAccounting(id, order, orderState, unfilledAmount);
    }
}
