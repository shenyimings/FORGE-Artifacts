// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Interface of the AbyssLockup smart contract.
 */
interface IAbyssLockup {

    /**
     * @dev Returns amount requested for the `token` withdrawal
     * on all `safeContract` smart contracts.
     */
    function deposited(address token) external view returns (uint256);

    /**
     * @dev Returns divFactor requested for the specific `token`.
     */
    function divFactor(address token) external view returns (uint256);

    /**
     * @dev Returns the amount of free deposits left.
     */
    function freeDeposits() external returns (uint256);

    /**
     * @dev Moves `amount` tokens from the `sender` account to `recipient`.
     *
     * This function can be called only by `safeContract` smart contracts: {onlyContract} modifier.
     *
     * All tokens are moved only from `AbyssLockup`smart contract so only one
     * token approval is required.
     *
     * Sets divFactor and deposit amount of specific `token`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function externalTransfer(address token, address sender, address recipient, uint256 amount, uint256 abyssRequired, uint256 balance, uint256 divFactor_) external returns (bool);

}
