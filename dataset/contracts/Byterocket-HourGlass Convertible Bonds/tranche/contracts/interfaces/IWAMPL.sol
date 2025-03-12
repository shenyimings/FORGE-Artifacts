// SPDX-License-Identifier: GPL-3.0-or-later
// derived from https://github.com/ampleforth/ampleforth-contracts
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface definition for WAMPL contract, A fixed-balance ERC-20 wrapper for the AMPL rebasing token.
interface IWAMPL is IERC20 {
    /// @notice Transfers AMPLs from {msg.sender} and mints wAMPLs.
    ///
    /// @param amples The amount of AMPLs to deposit.
    /// @return The amount of wAMPLs minted.
    function deposit(uint256 amples) external returns (uint256);

    /// @notice Burns wAMPLs from {msg.sender} and transfers AMPLs back.
    ///
    /// @param wamples The amount of wAMPLs to burn.
    /// @return The amount of AMPLs withdrawn.
    function burn(uint256 wamples) external returns (uint256);

    /// @return The address of the underlying "wrapped" token ie) AMPL.
    function underlying() external view returns (address);

    /// @param wamples The amount of wAMPL tokens.
    /// @return The amount of AMPL tokens exchangeable.
    function wrapperToUnderlying(uint256 wamples) external view returns (uint256);
}
