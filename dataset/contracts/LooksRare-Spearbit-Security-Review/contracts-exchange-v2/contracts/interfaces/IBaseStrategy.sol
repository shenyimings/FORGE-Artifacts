// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IBaseStrategy
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
interface IBaseStrategy {
    /**
     * @notice This function acts as a safety check for the protocol's owner when adding new execution strategies.
     * @return isStrategy Whether it is a LooksRare V2 protocol strategy
     */
    function isLooksRareV2Strategy() external pure returns (bool isStrategy);
}
