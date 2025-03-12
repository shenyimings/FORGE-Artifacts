// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interface for AutoFarm strategies.
 */
interface IStrat {

    /**
     * @dev Returns the total amount of shares in the strategy.
     */
    function sharesTotal() external view returns (uint256);

    /**
     * @dev Returns the total amount of want token locked in the strategy.
     */
    function wantLockedTotal() external view returns (uint256);

    /**
     * @dev Harvest XVS and convert into BCTB.
     */
    function earn() external;
}