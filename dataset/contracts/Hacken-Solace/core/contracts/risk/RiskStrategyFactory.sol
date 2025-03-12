// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "../utils/Governable.sol";
import "../utils/Factory.sol";
import "./RiskStrategy.sol";
import "./RiskManager.sol";
import "../interfaces/risk/IRiskStrategyFactory.sol";

/**
 * @title RiskStrategyFactory
 * @author solace.fi
 * @notice The **RiskStrategyFactory** manages the creation of new products.
 */
contract RiskStrategyFactory is Factory, IRiskStrategyFactory, Governable {

    /// @notice `Registry` contract.
    /// @dev It is immutable for gas savings.
    IRegistry internal immutable _registry;

    /**
     * @notice Constructs the `RiskStrategyFactory` contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param registry_ Address of registry.
     */
    constructor(address registry_, address governance_) Governable(governance_) {
        require(registry_ != address(0x0), "zero address registry");
        _registry = IRegistry(registry_);
    }

    /**
     * @notice Creates a new `Risk Strategy`.
     * @param base_ The strategy's source code.
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
    ) external override returns (address strategy) {
        strategy = _deployMinimalProxy(base_);
        RiskStrategy(strategy).initialize(
            this.governance(),
            _registry.get("riskManager"),
            msg.sender,
            products_,
            weights_,
            prices_,
            divisors_
        );
        emit StrategyCreated(strategy, msg.sender);
        return strategy;
   
    }

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
    ) external override returns (address strategy) {
        strategy = _deployMinimalProxy(base_, salt_);                                                                                                                
        RiskStrategy(strategy).initialize(
            this.governance(),
            _registry.get("riskManager"),
            msg.sender,
            products_,
            weights_,
            prices_,
            divisors_
        );
        emit StrategyCreated(strategy, msg.sender);
        return strategy;
    }
}
