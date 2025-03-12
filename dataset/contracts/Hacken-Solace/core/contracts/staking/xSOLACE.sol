// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./../interfaces/staking/IxsLocker.sol";
import "./../interfaces/staking/IxSOLACE.sol";


/**
 * @title xSolace Token (xSOLACE)
 * @author solace.fi
 * @notice The vote token of the Solace DAO.
 *
 * xSOLACE is the vote token of the Solace DAO. It masquerades as an ERC20 but cannot be transferred, minted, or burned, and thus has no economic value outside of voting.
 *
 * Balances are calculated based on **Locks** in [`xsLocker`](./xsLocker). The base value of a lock is its `amount` of [**SOLACE**](./../SOLACE). Its multiplier is 4x when `end` is 4 years from now, 1x when unlocked, and linearly decreasing between the two. The balance of a lock is its base value times its multiplier.
 *
 * [`balanceOf(user)`](#balanceof) is calculated as the sum of the balances of the user's locks. [`totalSupply()`](#totalsupply) is calculated as the sum of the balances of all locks. These functions should not be called on-chain as they are gas intensive.
 *
 * Voting will occur off chain.
 *
 * Note that transferring [**SOLACE**](./../SOLACE) to this contract will not give you any **xSOLACE**. You should deposit your [**SOLACE**](./../SOLACE) into [`xsLocker`](./xsLocker) via `createLock()`.
 */
// solhint-disable-next-line contract-name-camelcase
contract xSOLACE is IxSOLACE {

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice The maximum duration of a lock in seconds.
    uint256 public constant override MAX_LOCK_DURATION = 4 * 365 days; // 4 years
    /// @notice The vote power multiplier at max lock in bps.
    uint256 public constant override MAX_LOCK_MULTIPLIER_BPS = 40000;  // 4X
    /// @notice The vote power multiplier when unlocked in bps.
    uint256 public constant override UNLOCKED_MULTIPLIER_BPS = 10000; // 1X
    // 1 bps = 1/10000
    uint256 internal constant MAX_BPS = 10000;

    /// @notice The [**xsLocker**](./xsLocker) contract.
    address public override xsLocker;

    /**
     * @notice Constructs the **xSOLACE** contract.
     * @param xsLocker_ The [**xsLocker**](./xsLocker) contract.
     */
    constructor(address xsLocker_) {
        require(xsLocker_ != address(0x0), "zero address xslocker");
        xsLocker = xsLocker_;
    }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Returns the user's **xSOLACE** balance.
     * @param account The account to query.
     * @return balance The user's balance.
     */
    function balanceOf(address account) external view override returns (uint256 balance) {
        IERC721Enumerable locker = IERC721Enumerable(xsLocker);
        uint256 numOfLocks = locker.balanceOf(account);
        balance = 0;
        for (uint256 i = 0; i < numOfLocks; i++) {
            uint256 xsLockID = locker.tokenOfOwnerByIndex(account, i);
            balance += balanceOfLock(xsLockID);
        }
        return balance;
    }

    /**
     * @notice Returns the **xSOLACE** balance of a lock.
     * @param xsLockID The lock to query.
     * @return balance The locks's balance.
     */
    function balanceOfLock(uint256 xsLockID) public view override returns (uint256 balance) {
        IxsLocker locker = IxsLocker(xsLocker);
        Lock memory lock = locker.locks(xsLockID);
        uint256 base = lock.amount * UNLOCKED_MULTIPLIER_BPS / MAX_BPS;
        // solhint-disable-next-line not-rely-on-time
        uint256 bonus = (lock.end <= block.timestamp)
            ? 0 // unlocked
            // solhint-disable-next-line not-rely-on-time
            : lock.amount * (lock.end - block.timestamp) * (MAX_LOCK_MULTIPLIER_BPS - UNLOCKED_MULTIPLIER_BPS) / (MAX_LOCK_DURATION * MAX_BPS); // locked
        return base + bonus;
    }

    /**
     * @notice Returns the total supply of **xSOLACE**.
     * @return supply The total supply.
     */
    function totalSupply() external view override returns (uint256 supply) {
        IERC721Enumerable locker = IERC721Enumerable(xsLocker);
        uint256 numOfLocks = locker.totalSupply();
        supply = 0;
        for (uint256 i = 0; i < numOfLocks; i++) {
            uint256 xsLockID = locker.tokenByIndex(i);
            supply += balanceOfLock(xsLockID);
        }
        return supply;
    }

    /**
     * @notice Returns the name of the token.
     */
    function name() external pure override returns (string memory) {
        return "xsolace";
    }

    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() external pure override returns (string memory) {
        return "xSOLACE";
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     */
    function decimals() external pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through `transferFrom`.
     */
    // solhint-disable-next-line no-unused-vars
    function allowance(address owner, address spender) external pure override returns (uint256) {
        return 0;
    }

    /***************************************
    MUTATOR FUNCTIONS
    ***************************************/

    /**
     * @notice In a normal ERC20 contract this would move `amount` tokens from the caller's account to `recipient`.
     * This version reverts because **xSOLACE** is non-transferrable.
     * @param recipient The user to send tokens to.
     * @param amount The amount of tokens to send.
     * @return success False.
     */
    // solhint-disable-next-line no-unused-vars
    function transfer(address recipient, uint256 amount) external override returns (bool success) {
        revert("xSOLACE transfer not allowed");
    }

    /**
     * @notice In a normal ERC20 contract this would move `amount` tokens from `sender` to `recipient` using allowance.
     * This version reverts because **xSOLACE** is non-transferrable.
     * @param recipient The user to send tokens to.
     * @param amount The amount of tokens to send.
     * @return success False.
     */
    // solhint-disable-next-line no-unused-vars
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool success) {
        revert("xSOLACE transfer not allowed");
    }

    /**
     * @notice In a normal ERC20 contract this would set `amount` as the allowance of `spender` over the caller's tokens.
     * This version reverts because **xSOLACE** is non-transferrable.
     * @param spender The user to assign allowance.
     * @param amount The amount of tokens to send.
     * @return success False.
     */
    // solhint-disable-next-line no-unused-vars
    function approve(address spender, uint256 amount) external override returns (bool success) {
        revert("xSOLACE transfer not allowed");
    }
}
