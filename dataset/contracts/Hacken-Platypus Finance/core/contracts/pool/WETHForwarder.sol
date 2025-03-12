// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Address.sol';

import '../interfaces/IWETH.sol';
import '../interfaces/IWETHForwarder.sol';

/**
 * @title WETHForwarder
 * @notice Temporary WAVAX holder
 * @dev Unwraps and forwards actual AVAX to user
 * @dev Allows transfer of WAVAX (called `weth` here).
 */
contract WETHForwarder is Ownable, ReentrancyGuard, IWETHForwarder {
    using Address for address payable;

    /// @notice Weth (or wavax in our case) address
    address public weth;

    /// @notice Pool address
    address public pool;

    /// @notice An event thats emitted when pool is updated
    event PoolUpdated(address indexed previousPool, address indexed newPool);

    /// @dev Modifier ensuring that certain function can only be called by pool
    modifier onlyPool() {
        require(msg.sender == pool, 'FORBIDDEN');
        _;
    }

    /**
     * @notice Constructor.
     * @param weth_ The weth (or wavax) address to be used.
     */
    constructor(address weth_) {
        require(weth_ != address(0), 'ADDRESS_ZERO');
        weth = weth_;
    }

    receive() external payable {
        assert(msg.sender == weth); // only accept ETH via fallback from the WETH contract
    }

    /**
     * @notice Changes the pool. Can only be set by the contract owner.
     * @param pool_ new contract pool address
     */
    function setPool(address pool_) external onlyOwner {
        require(pool_ != address(0), 'Pool address cannot be zero');
        emit PoolUpdated(pool, pool_);
        pool = pool_;
    }

    /**
     * @notice Unwrap and transfer eth. Can only be called by pool
     * @param to address receiving
     * @param amount total amount to be transferred
     */
    function unwrapAndTransfer(address payable to, uint256 amount) external onlyPool nonReentrant {
        IWETH _weth = IWETH(weth);
        require(_weth.balanceOf(address(this)) >= amount, 'INSUFFICIENT_WETH');
        _weth.withdraw(amount);
        to.sendValue(amount);
    }
}
