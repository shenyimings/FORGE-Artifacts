//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

import "../interfaces/IInvariantCheck.sol";
import "../interfaces/IPoolCommitter.sol";
import "../interfaces/IPausable.sol";
import "../interfaces/ILeveragedPool.sol";
import "../interfaces/IPoolFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title The contract for checking invariants and pausing if necessary
/// @notice Every time certain functions are called, known invariants are checked and if any do not hold, contracts are paused.
contract InvariantCheck is IInvariantCheck {
    IPoolFactory public immutable poolFactory;

    /**
     * @notice Constructor
     * @param _factory Address of the associated `PoolFactory` contract
     * @dev Throws if factory address is null
     */
    constructor(address _factory) {
        require(_factory != address(0), "Factory address cannot be null");
        poolFactory = IPoolFactory(_factory);
    }

    /**
     * @notice Checks all invariants, and pauses all contracts if
     *         any invariant does not hold.
     * @dev This should be called before onlyUnpaused, in case contracts are paused then pause check must happen after.
     * @dev Emits `InvariantsHold` event if invariants hold.
     * @param poolToCheck The LeveragedPool contract to be checked.
     */
    function checkInvariants(address poolToCheck) external override {
        ILeveragedPool pool = ILeveragedPool(poolToCheck);
        require(poolFactory.isValidPool(poolToCheck), "Pool is invalid");
        IPoolCommitter poolCommitter = IPoolCommitter(pool.poolCommitter());
        uint256 poolBalance = IERC20(pool.quoteToken()).balanceOf(poolToCheck);
        uint256 pendingMints = poolCommitter.totalPendingMints();
        uint256 longBalance = pool.longBalance();
        uint256 shortBalance = pool.shortBalance();
        if (!balanceInvariant(poolBalance, pendingMints, longBalance, shortBalance)) {
            pause(IPausable(poolToCheck), IPausable(address(poolCommitter)));
            emit InvariantsFail("Balance invariant fails");
        }
        emit InvariantsHold();
    }

    /**
     * @notice Pause both LeveragedPool and PoolCommitter.
     * @dev Both parameters must implement the IPausable interface.
     * @param pool The LeveragedPool to be paused.
     * @param poolCommitter The PoolCommitter to be paused.
     */
    function pause(IPausable pool, IPausable poolCommitter) internal {
        pool.pause();
        poolCommitter.pause();
    }

    /**
     * @notice Check that the balance of a pool is equal to or greater than the summation of pending mints, long balance and short balance
     * @return true if balance invariant holds. False if not
     * @param balance The amount of settlement tokens owned by the leveraged pool
     * @param pendingMints The amount of pending mints in the pool
     * @param longBalance The balance of the long side of the pool
     * @param shortBalance The balance of the short side of the pool
     */
    function balanceInvariant(
        uint256 balance,
        uint256 pendingMints,
        uint256 longBalance,
        uint256 shortBalance
    ) internal pure returns (bool) {
        return balance >= pendingMints + longBalance + shortBalance;
    }
}
