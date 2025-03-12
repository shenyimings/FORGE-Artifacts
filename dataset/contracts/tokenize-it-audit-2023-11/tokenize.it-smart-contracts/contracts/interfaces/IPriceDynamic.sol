// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

/**
 * @title IPriceDynamic
 * @author malteish
 * @notice The price dynamic interface is used by the Crowdinvesting contract to change price over time.
 * The interface consists of only one function. Any logic can be implemented in the contract that implements this interface.
 * If a contract implementing this interface needs more information from the Crowdinvesting contract, it can
 * call the Crowdinvesting contract's public functions to obtain this information.
 */
interface IPriceDynamic {
    function getPrice(uint256 basePrice) external view returns (uint256);
}
