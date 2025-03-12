// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../ISwapData.sol";

interface ISpoolExternal {
    /* ========== FUNCTIONS ========== */

    function deposit(address strategy, uint128 amount, uint256 index) external;

    function withdraw(address strategy, uint256 vaultProportion, uint256 index) external;

    function fastWithdrawStrat(address strat, address underlying, uint256 shares, uint256[] calldata slippages, SwapData[] calldata swapData) external returns(uint128);

    function redeem(address strat, uint256 index) external returns (uint128, uint128);

    function redeemUnderlying(uint128 amount) external;

    function redeemReallocation(address[] calldata vaultStrategies, uint256 depositProportions, uint256 index) external;

    function removeShares(address[] calldata vaultStrategies, uint256 vaultProportion) external returns(uint128[] memory);

    function removeSharesDuringVaultReallocation(
        VaultWithdraw calldata vaultWithdraw,
        FastWithdrawalReallocation calldata reallocation,
        uint256[][] calldata reallocationProportions
    ) external returns(uint128[] memory);

    /* ========== STRUCTS ========== */

    // holds helper values to remove shares while vault is reallocating
    struct FastWithdrawalReallocation {
        uint256 vaultStrategiesBitwise;
        address[] allStrategies;
        uint256 depositProportions;
    }

    struct VaultWithdraw {
        address[] strategies;
        uint256 withdrawnProportion;
    }

    /* ========== EVENTS ========== */
    
    event SpoolDeposit(address indexed vault, address indexed strat);
    event SpoolWithdraw(address indexed vault, address indexed strat);
    event SpoolRedeem(address indexed vault, address indexed strat);
    event SpoolRedeemReallocation(address indexed vault);
    event SpoolSharesRemoved(address indexed vault);
    event SpoolSharesRemovedReallocating(address indexed vault);
}
