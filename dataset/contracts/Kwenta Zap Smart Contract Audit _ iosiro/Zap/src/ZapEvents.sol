// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

/// @title Zap contract events
/// @author JaredBorders (jaredborders@pm.me)
contract ZapEvents {
    /// @notice emitted after successful $USDC -> $sUSD zap
    /// @param amountWrapped amount of $USDC wrapped
    /// @param amountMinted amount of $sUSD minted
    event ZappedIn(uint256 amountWrapped, uint256 amountMinted);

    /// @notice emitted after successful $sUSD -> $USDC zap
    /// @param amountBurned amount of $sUSD burned
    /// @param amountUnwrapped amount of $USDC unwrapped
    event ZappedOut(uint256 amountBurned, uint256 amountUnwrapped);
}
