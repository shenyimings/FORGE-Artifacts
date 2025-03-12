// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interface/IStrategy.sol";

/**
 * @title Aspida's CoreStrategy module
 * @dev This contract is an abstract contract that defines the core strategy functions and variables.
 * @author Aspida engineer
 */
abstract contract CoreStrategy {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant MAX_RESERVE_RATIO = 1e18;

    uint256 internal reserveRatio_;
    uint256 internal strategyReserve_;
    uint256 internal depositStrategy_;
    uint256 internal receiveStrategy_;

    /// @dev EnumerableSet of strategists
    EnumerableSet.AddressSet internal strategists_;

    /**
     * @dev Emitted when "reserveRatio_" has changed.
     */
    event SetReserveRatio(uint256 reserveRatio);

    /**
     * @dev Emitted when "strategyReserve_" has been updated.
     */
    event UpdateStrategyReserve(uint256 strategyReserve);

    /**
     * @dev Emitted when 'strategy' is added to 'strategists_'.
     */
    event StrategyAdded(address strategy);

    /**
     * @dev Emitted when `strategy` is removed from `strategists_`.
     */
    event StrategyRemoved(address strategy);

    /**
     * @dev Emitted when a deposit is made to a `strategy`.
     */
    event DepositToStrategy(address strategy, uint256 amount);

    /**
     * @dev Emitted when an amount is received from a `strategy`.
     */
    event ReceiveFromStrategy(address strategy, uint256 amount);

    /**
     * @dev Throws an exception if strategic addresses are not enabled.
     */
    modifier isStrategy(address _strategy) {
        require(strategists_.contains(_strategy), "isStrategy: invalid strategy address");
        _;
    }

    /**
     * @notice Set the reserve ratio internally.
     * @dev This function sets the reserve ratio to the specified value.
     * @param _reserveRatio The new reserve ratio to be set.
     */
    function _setReserveRatioInternal(uint256 _reserveRatio) internal {
        require(_reserveRatio <= MAX_RESERVE_RATIO, "_setReserveRatioInternal: ReserveRatio too large");
        require(_reserveRatio != reserveRatio_, "_setReserveRatioInternal: Cannot set the same value");
        reserveRatio_ = _reserveRatio;
        emit SetReserveRatio(_reserveRatio);
    }

    /**
     * @notice Add `strategy` into strategists_.
     * If `strategy` have not been a strategy, emits a `StrategyAdded` event.
     *
     * @param _strategy The strategy to add
     */
    function _addStrategyInternal(address _strategy) internal virtual {
        require(
            _strategy != address(0) && IStrategy(_strategy).core() == address(this),
            "_addStrategyInternal: invalid strategy address"
        );
        require(strategists_.add(_strategy), "_addStrategyInternal: Strategy has been added");
        emit StrategyAdded(_strategy);
    }

    /**
     * @notice Remove `strategy` from strategists_.
     * If `strategy` is a strategy, emits a `StrategyRemoved` event.
     *
     * @param _strategy The strategy to remove
     */
    function _removeStrategyInternal(address _strategy) internal virtual {
        require(strategists_.remove(_strategy), "_removeStrategyInternal: Strategy has been removed");
        emit StrategyRemoved(_strategy);
    }

    /**
     * @notice Update the strategy reserve with the specified value.
     * @dev This function updates the strategy reserve to the given value.
     * @param _strategyReserve The new value for the strategy reserve.
     */
    function _updateStrategyReserve(uint256 _strategyReserve) internal {
        strategyReserve_ = _strategyReserve;
        emit UpdateStrategyReserve(_strategyReserve);
    }

    /**
     * @notice Increase the strategy reserve by the specified amount.
     * @dev This function increases the strategy reserve by the given amount.
     * @param _increaseReserve The amount to increase the strategy reserve by.
     */
    function _increaseStrategyReserve(uint256 _increaseReserve) internal {
        _updateStrategyReserve(strategyReserve_ + _increaseReserve);
    }

    /**
     * @notice Decrease the strategy reserve by the specified amount.
     * @dev This function decreases the strategy reserve by the given amount.
     * @param _decreaseReserve The amount to decrease the strategy reserve by.
     */
    function _decreaseStrategyReserve(uint256 _decreaseReserve) internal {
        _updateStrategyReserve(strategyReserve_ - _decreaseReserve);
    }

    /**
     * @notice Increase the reserves by a ratio of the specified amount.
     * @dev This function increases the reserves by a ratio of the given amount.
     * @param _amount The amount to increase the reserves by.
     */
    function _increaseReservesByRatio(uint256 _amount) internal {
        _increaseStrategyReserve((_amount * reserveRatio_) / MAX_RESERVE_RATIO);
    }

    /**
     * @notice Deposit ETH into the specified strategy.
     * @dev This function deposits the specified amount of ETH into the strategy.
     * @param _strategy The address of the strategy to deposit into.
     * @param _ethAmount The amount of ETH to deposit.
     */
    function _depositIntoStrategyInternal(
        address _strategy,
        uint256 _ethAmount
    ) internal virtual isStrategy(_strategy) {
        _decreaseStrategyReserve(_ethAmount);
        depositStrategy_ += _ethAmount;
        IStrategy(_strategy).strategyReceive{ value: _ethAmount }();
        emit DepositToStrategy(_strategy, _ethAmount);
    }

    /**
     * @notice Receive strategy earnings from the specified strategy.
     * @dev This function receives the earnings from the specified strategy.
     * @param _strategy The address of the strategy to receive earnings from.
     */
    function _receiveStrategyEarning(address _strategy) internal virtual isStrategy(_strategy) {
        uint256 _ethValue = msg.value;
        _increaseStrategyReserve(_ethValue);
        receiveStrategy_ += _ethValue;
        emit ReceiveFromStrategy(_strategy, _ethValue);
    }

    /**
     * @notice Get the reserve ratio.
     * @return The reserve ratio.
     */
    function reserveRatio() external view returns (uint256) {
        return reserveRatio_;
    }

    /**
     * @notice Get the strategy reserve.
     * @return The strategy reserve.
     */
    function strategyReserve() external view returns (uint256) {
        return strategyReserve_;
    }

    /**
     * @notice Get the deposit strategy.
     * @return The deposit strategy.
     */
    function depositStrategy() external view returns (uint256) {
        return depositStrategy_;
    }

    /**
     * @notice Get the receive strategy.
     * @return The receive strategy.
     */
    function receiveStrategy() external view returns (uint256) {
        return receiveStrategy_;
    }

    /**
     * @notice Get all strategists.
     * @return _strategists The list of strategy addresses.
     */
    function strategists() external view returns (address[] memory _strategists) {
        _strategists = strategists_.values();
    }
}
