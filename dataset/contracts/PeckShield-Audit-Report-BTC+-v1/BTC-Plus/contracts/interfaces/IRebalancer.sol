// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @title Interface of BTC+ pools rebalancer.
 */
interface IRebalancer {

    /**
     * @dev Performs rebalance after receiving the requested tokens.
     * @param _tokens Address of the tokens received from BTC+ pools.
     * @param _amounts Amounts of the tokens received from BTC+ pools.
     * @param _data Data to invoke on rebalancer contract.
     */
    function rebalance(address[] calldata _tokens, uint256[] calldata _amounts, bytes calldata _data) external;
}