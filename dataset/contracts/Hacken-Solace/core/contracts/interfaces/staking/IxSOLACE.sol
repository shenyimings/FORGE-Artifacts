// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


/**
 * @title xSolace Token (xSOLACE)
 * @author solace.fi
 * @notice The vote token of the Solace DAO.
 *
 * **xSOLACE** is the vote token of the Solace DAO. It masquerades as an ERC20 but cannot be transferred, minted, or burned, and thus has no economic value outside of voting.
 *
 * Balances are calculated based on **Locks** in [`xsLocker`](./../../staking/xsLocker). The base value of a lock is its `amount` of [**SOLACE**](./../../SOLACE). Its multiplier is 4x when `end` is 4 years from now, 1x when unlocked, and linearly decreasing between the two. The balance of a lock is its base value times its multiplier.
 *
 * [`balanceOf(user)`](#balanceof) is calculated as the sum of the balances of the user's locks. [`totalSupply()`](#totalsupply) is calculated as the sum of the balances of all locks. These functions should not be called on-chain as they are gas intensive.
 *
 * Voting will occur off chain.
 *
 * Note that transferring [**SOLACE**](./../../SOLACE) to this contract will not give you any **xSOLACE**. You should deposit your [**SOLACE**](./../../SOLACE) into [`xsLocker`](./../../staking/xsLocker) via `createLock()`.
 */
interface IxSOLACE is IERC20Metadata {

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice The maximum duration of a lock in seconds.
    function MAX_LOCK_DURATION() external view returns (uint256);
    /// @notice The vote power multiplier at max lock in bps.
    function MAX_LOCK_MULTIPLIER_BPS() external view returns (uint256);
    /// @notice The vote power multiplier when unlocked in bps.
    function UNLOCKED_MULTIPLIER_BPS() external view returns (uint256);

    /// @notice The [`xsLocker`](./../../staking/xsLocker) contract.
    function xsLocker() external view returns (address);

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Returns the **xSOLACE** balance of a lock.
     * @param xsLockID The lock to query.
     * @return balance The locks's balance.
     */
    function balanceOfLock(uint256 xsLockID) external view returns (uint256 balance);
}
