// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 * @title ERC20 Token Standard, optional extension: Burnable
 * Note: the ERC-165 identifier for this interface is 0x3b5a0bf8.
 */
interface IERC20Burnable {
    /**
     * Burns `value` tokens from the message sender, decreasing the total supply.
     * @dev Reverts if the sender owns less than `value` tokens.
     * @dev Emits a {IERC20-Transfer} event with `_to` set to the zero address.
     * @param value the amount of tokens to burn.
     * @return a boolean value indicating whether the operation succeeded.
     */
    function burn(uint256 value) external returns (bool);

    /**
     * Burns `value` tokens from `from`, using the allowance mechanism and decreasing the total supply.
     * @dev Reverts if `from` owns less than `value` tokens.
     * @dev Reverts if `from` is not the sender and the sender is not approved by `from` for at least `value` tokens.
     * @dev Emits a {IERC20-Transfer} event with `_to` set to the zero address.
     * @dev Emits a {IERC20-Approval} event if `from` is not the sender (non-standard).
     * @param from the account to burn the tokens from.
     * @param value the amount of tokens to burn.
     * @return a boolean value indicating whether the operation succeeded.
     */
    function burnFrom(address from, uint256 value) external returns (bool);

    /**
     * Burns `values` tokens from `owners`, decreasing the total supply.
     * @dev Reverts if one `owners` and `values` have different lengths.
     * @dev Reverts if one of `owners` owns less than the corresponding `value` tokens.
     * @dev Reverts if one of `owners` is not the sender and the sender is not approved the corresponding `owner` and `value`.
     * @dev Emits a {IERC20-Transfer} event with `_to` set to the zero address.
     * @dev Emits a {IERC20-Approval} event (non-standard).
     * @param owners the accounts to burn the tokens from.
     * @param values the amounts of tokens to burn.
     * @return a boolean value indicating whether the operation succeeded.
     */
    function batchBurnFrom(address[] calldata owners, uint256[] calldata values) external returns (bool);
}
