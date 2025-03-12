//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

/// @title The contract factory for the keeper and pool contracts. Utilizes minimal clones to keep gas costs low
interface IInvariantCheck {
    event InvariantsHold();
    event InvariantsFail(string message);

    /**
     * @notice Checks all invariants, and pauses all contracts if
     *         any invariant does not hold.
     */
    function checkInvariants(address pool) external;
}
