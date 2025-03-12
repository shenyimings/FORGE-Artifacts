// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 * @title ERC20 Token Standard, optional extension: Mintable
 */
interface IERC20Mintable {
    /**
     * Mints `value` tokens and assigns them to `to`, increasing the total supply.
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if the total supply overflows.
     * @dev Emits a {IERC20-Transfer} event with `from` set to the zero address.
     * @param to the account to deliver the tokens to.
     * @param value the amount of tokens to mint.
     */
    function mint(address to, uint256 value) external;

    /**
     * Mints `values` tokens and assigns them to `recipients`, increasing the total supply.
     * @dev Reverts if `recipients` and `values` have different lengths.
     * @dev Reverts if one of `recipients` is the zero address.
     * @dev Reverts if the total supply overflows.
     * @dev Emits an {IERC20-Transfer} event for each transfer with `_from` set to the zero address.
     * @param recipients the accounts to deliver the tokens to.
     * @param values the amounts of tokens to mint to each of `recipients`.
     */
    function batchMint(address[] calldata recipients, uint256[] calldata values) external;
}
