// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "./IPolicyManager.sol";
import "../utils/IRegistry.sol";

/**
 * @title IRiskStrategyFactory
 * @author solace.fi
 * @notice The interface of **RiskStrategyFactory** that manages the creation of new strategies.
 */
interface IRiskStrategyFactory {

    /***************************************
    EVENTS
    ***************************************/
    /// @notice Emitted when new strategy is created.
    event StrategyCreated(address strategy, address strategist);

    /**
     * @notice Creates a new `Risk Strategy`.
     * @param base_  The strategy's source code.
     * @param products_ The strategy products.
     * @param weights_  The weights of the strategy products.
     * @param prices_   The prices of the strategy products.
     * @param divisors_ The divisors(max cover per policy divisor) of the strategy products. 
     * @return strategy The address of newly created strategy.
    */
    function createRiskStrategy(
        address base_,
        address[] memory products_, 
        uint32[] memory weights_, 
        uint24[] memory prices_,
        uint16[] memory divisors_
    ) external returns (address strategy);

    /**
     * @notice Creates a new `Risk Strategy`.
     * @param base_  The strategy's source code.
     * @param salt_ The salt for CREATE2.
     * @param products_ The strategy products.
     * @param weights_  The weights of the strategy products.
     * @param prices_   The prices of the strategy products.
     * @param divisors_ The divisors(max cover per policy divisor) of the strategy products. 
     * @return strategy The address of newly created strategy.
    */
    function create2RiskStrategy(
        address base_,
        bytes32 salt_,
        address[] memory products_, 
        uint32[] memory weights_, 
        uint24[] memory prices_,
        uint16[] memory divisors_
    ) external returns (address strategy);
}