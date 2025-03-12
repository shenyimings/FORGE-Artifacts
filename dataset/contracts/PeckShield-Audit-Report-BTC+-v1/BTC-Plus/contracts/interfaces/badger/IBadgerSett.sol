// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interface for Badger Sett.
 */
interface IBadgerSett {

    function getPricePerFullShare() external view returns (uint256);

}