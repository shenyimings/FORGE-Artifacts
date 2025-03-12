// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

/// @title Reduced Interface of the ERC20 standard as defined in the EIP
/// @author OpenZeppelin
interface IERC20 {
    /// @dev Returns the number of decimals used to get its user representation.
    /// For example, if `decimals` equals `2`, a balance of `505` tokens should
    /// be displayed to a user as `5.05` (`505 / 10 ** 2`).
    function decimals() external view returns (uint8);

    /// @dev Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256);

    /// @dev Moves `amount` tokens from the caller's account to `to`
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to transfer
    /// @return a boolean value indicating whether the operation succeeded
    /// Emits a {Transfer} event
    function transfer(address to, uint256 amount) external returns (bool);

    /// @dev Sets `amount` as the allowance of `spender` over the caller's tokens
    /// @param spender The address of the account to grant the allowance
    /// @param amount The amount of tokens to allow
    /// @return a boolean value indicating whether the operation succeeded
    /// Emits an {Approval} event.
    function approve(address spender, uint256 amount) external returns (bool);

    /// @dev Moves `amount` tokens from `from` to `to` using the
    /// allowance mechanism. `amount` is then deducted from the caller's
    /// allowance
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to transfer
    /// @return a boolean value indicating whether the operation succeeded.
    /// Emits a {Transfer} event
    function transferFrom(address from, address to, uint256 amount)
        external
        returns (bool);
}
