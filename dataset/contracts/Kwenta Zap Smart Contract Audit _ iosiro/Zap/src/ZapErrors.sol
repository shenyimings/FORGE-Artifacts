// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

/// @title Zap contract errors
/// @author JaredBorders (jaredborders@pm.me)
contract ZapErrors {
    /// @notice thrown when $USDC address is zero
    /// @dev only can be thrown in during Zap deployment
    error USDCZeroAddress();

    /// @notice thrown when $sUSD address is zero
    /// @dev only can be thrown in during Zap deployment
    error SUSDZeroAddress();

    /// @notice thrown when Synthetix v3 Spot Market Proxy
    /// address is zero
    /// @dev only can be thrown in during Zap deployment
    error SpotMarketZeroAddress();

    /// @notice thrown when the given Synthetix v3 Spot Market ID
    /// for $sUSDC is incorrect; querying the Spot Market Proxy
    /// contract for the name of the Spot Market ID returns
    /// a different name than expected
    /// @dev only can be thrown in during Zap deployment
    /// @param id Synthetix v3 Spot Market ID for $sUSDC
    error InvalidIdSUSDC(uint128 id);

    /// @notice thrown when a given token transfer fails
    /// @param token address of the token contract
    /// @param from address of the sender
    /// @param to address of the recipient
    /// @param amount amount of tokens to transfer
    error TransferFailed(
        address token, address from, address to, uint256 amount
    );

    /// @notice thrown when a given token approval fails
    /// @param token address of the token contract
    /// @param owner address of the token owner
    /// @param spender address of the spender
    /// @param amount amount of tokens to approve
    error ApprovalFailed(
        address token, address owner, address spender, uint256 amount
    );

    /// @notice thrown when the given amount is insufficient
    /// due to decimals adjustment
    /// @param amount amount of tokens to transfer
    /// @custom:example if $USDC has 6 decimals, and
    /// $sUSDC has greater than 6 decimals,
    /// then it is possible that the amount of
    /// $sUSDC to unwrap is less than 1 $USDC
    error InsufficientAmount(uint256 amount);
}
