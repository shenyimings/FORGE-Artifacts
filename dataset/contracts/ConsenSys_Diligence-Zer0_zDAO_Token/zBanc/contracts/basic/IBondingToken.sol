// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


/**
 * @title IBondingToken
 * @dev Interface for the BondingToken contract.
 */
interface IBondingToken {
    /**
     * @dev Sets the entry fee.
     * @param entryFeeBasisPoints The new entry fee in basis points. Must not exceed 50%.
     */
    function setEntryFee(uint256 entryFeeBasisPoints) external;

    /**
     * @dev Sets the exit fee.
     * @param exitFeeBasisPoints The new exit fee in basis points. Must not exceed 50%.
     */
    function setExitFee(uint256 exitFeeBasisPoints) external;
}
