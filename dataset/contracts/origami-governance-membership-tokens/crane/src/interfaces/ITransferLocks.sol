// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface ITransferLocks {
    /**
     * @notice Used to voluntarily lock up `amount` tokens until a given time. Tokens in excess of `amount` may be transferred.
     * @dev Block timestamp may be innaccurate by up to 15 minutes, but on a timescale of years this is negligible.
     * @param amount the amount of tokens to restrict the transfer of.
     * @param deadline the date (as a unix timestamp in UTC) until which amount will be untransferrable.
     */
    function addTransferLock(uint256 amount, uint256 deadline) external;

    /**
     * @notice Returns the number of transfer locks `account` has permitted `recipient`.
     * @param account the address that granted the allowance.
     * @param recipient the address that is allowed to add transfer locks.
     */
    function allowances(address account, address recipient) external view returns (uint8);

    /**
     * @notice Used to increase the number of transfer locks that can be added
     * by another address. Only allowing a limited number of locks to be added
     * by a given address prevents a variety of potentially abusive patterns.
     * @param account the address to increase the allowance for.
     * @param amount the amount to increase the allowance by.
     */
    function increaseTransferLockAllowance(address account, uint8 amount) external;

    /**
     * @notice Used to decrease the number of transfer locks that can be added
     * by another address. This cannot be used to revoke or otherwise remove an
     * existing transfer lock, only to reduce the number of additional locks
     * that can be added by the specified account.
     * @param account the address to decrease the allowance for.
     * @param amount the amount to decrease the allowance by.
     */
    function decreaseTransferLockAllowance(address account, uint8 amount) external;

    /**
     * @notice Returns the total amount locked up as of current block.timestamp. Returns 0 if there are no transfer locks.
     * @param account the address to check.
     * @return amount the amount of tokens that are transfer-locked.
     */
    function getTransferLockTotal(address account) external view returns (uint256 amount);

    /**
     * @notice Returns the total amount locked up as of the given timestamp. Returns 0 if there are no transfer locks.
     * @param account the address to check.
     * @param timestamp the timestamp to check at.
     * @return amount the amount of tokens that are transfer-locked.
     */
    function getTransferLockTotalAt(address account, uint256 timestamp) external view returns (uint256 amount);

    /**
     * @notice Returns the amount of tokens that are not locked up as of current block.timestamp.
     * @param account the address to check.
     * @return amount the amount of tokens that are not transfer-locked.
     */
    function getAvailableBalance(address account) external view returns (uint256 amount);

    /**
     * @notice Retrieves the balance of an account that is not locked at a given timestamp.
     * @param account the address to check.
     * @param timestamp the timestamp to check.
     * @return amount the amount of tokens that are not transfer-locked.
     */
    function getAvailableBalanceAt(address account, uint256 timestamp) external view returns (uint256 amount);

    /**
     * @notice Used to transfer tokens to an address and lock them up until a given time.
     * @dev block timestamp may be innaccurate by up to 15 minutes, but on the expected timescales, this is negligible.
     * @param recipient the address to transfer tokens to.
     * @param amount the amount of tokens to transfer.
     * @param deadline the date (as a unix timestamp in UTC) until which amount will be untransferrable.
     */
    function transferWithLock(address recipient, uint256 amount, uint256 deadline) external;

    /**
     * @notice Used to transfer tokens to multiple addresses and lock them up until a given time.
     * @dev block timestamp may be innaccurate by up to 15 minutes, but on the expected timescales, this is negligible.
     * @param recipients the addresses to transfer tokens to.
     * @param amounts the amounts of tokens to transfer.
     * @param deadlines the dates (as unix timestamps in UTC) until which amounts will be untransferrable.
     */
    function batchTransferWithLocks(
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256[] calldata deadlines
    ) external;
}
