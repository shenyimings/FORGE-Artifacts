// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

struct TokenAmount {
    /// @notice The asset token redeemed.
    IERC20Upgradeable token;
    /// @notice The amount redeemed.
    uint256 amount;
}

/// @notice The system subscription parameters.
struct SubscriptionParams {
    /// @notice The current TVL of perp denominated in the underlying.
    uint256 perpTVL;
    /// @notice The current TVL of the vault denominated in the underlying.
    uint256 vaultTVL;
    /// @notice The tranche ratio of seniors accepted by perp.
    uint256 seniorTR;
}

struct RolloverData {
    /// @notice The amount of tokens rolled out.
    uint256 tokenOutAmt;
    /// @notice The amount of trancheIn tokens rolled in.
    uint256 trancheInAmt;
}
