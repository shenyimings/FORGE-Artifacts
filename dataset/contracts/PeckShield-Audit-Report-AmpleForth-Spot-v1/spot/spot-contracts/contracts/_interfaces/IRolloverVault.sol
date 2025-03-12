// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVault } from "./IVault.sol";
import { SubscriptionParams } from "./CommonTypes.sol";

interface IRolloverVault is IVault {
    /// @notice Allows users to swap their underlying tokens for perps held by the vault.
    /// @param underlyingAmtIn The amount of underlying tokens swapped in.
    /// @return The amount of perp tokens swapped out.
    function swapUnderlyingForPerps(uint256 underlyingAmtIn) external returns (uint256);

    /// @notice Allows users to swap their perp tokens for underlying tokens held by the vault.
    /// @param perpAmtIn The amount of perp tokens swapped in.
    /// @return The amount of underlying tokens swapped out.
    function swapPerpsForUnderlying(uint256 perpAmtIn) external returns (uint256);

    /// @notice Computes the amount of perp tokens that are returned when user swaps a given number of underlying tokens.
    /// @param underlyingAmtIn The number of underlying tokens the user swaps in.
    /// @return perpAmtOut The number of perp tokens returned to the user.
    /// @return perpFeeAmtToBurn The amount of perp tokens to be paid to the perp contract as mint fees.
    /// @return s The pre-swap perp and vault subscription state.
    function computeUnderlyingToPerpSwapAmt(
        uint256 underlyingAmtIn
    ) external returns (uint256, uint256, SubscriptionParams memory);

    /// @notice Computes the amount of underlying tokens that are returned when user swaps a given number of perp tokens.
    /// @param perpAmtIn The number of perp tokens the user swaps in.
    /// @return underlyingAmtOut The number of underlying tokens returned to the user.
    /// @return perpFeeAmtToBurn The amount of perp tokens to be paid to the perp contract as burn fees.
    /// @return s The pre-swap perp and vault subscription state.
    function computePerpToUnderlyingSwapAmt(
        uint256 perpAmtIn
    ) external returns (uint256, uint256, SubscriptionParams memory);

    /// @return The system's current deviation ratio.
    function deviationRatio() external returns (uint256);
}
