// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./IVaultDetails.sol";

interface IVaultIndexActions {
    /* ========== FUNCTIONS ========== */

    function initialize(VaultInitializable calldata vaultInitializable) external;

    /* ========== STRUCTS ========== */

    struct IndexAction {
        uint128 depositAmount;
        uint128 withdrawShares;
    }

    struct LastIndexInteracted {
        uint128 index1;
        uint128 index2;
    }

    struct Redeem {
        uint128 depositShares;
        uint128 withdrawnAmount;
    }

    /* ========== EVENTS ========== */

    event VaultRedeem(uint indexed vaultIndex);
    event UserRedeem(address indexed member, uint indexed vaultIndex);
}
