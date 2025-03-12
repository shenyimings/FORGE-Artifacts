// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @dev Interface for ACoconutMaker
 */
interface IACoconutMaker {

    /**
     * @dev Returns the amount of acBTC for each acBTCx.
     */
    function exchangeRate() external view returns (uint256);

    /**
     * @dev Mints acBTCx with acBTC.
     * @param _amount Amount of acBTC used to mint acBTCx.
     */
    function mint(uint256 _amount) external;

    /**
     * @dev Redeems acBTCx to acBTC.
     * @param _share Amount of acBTCx to redeem.
     */
    function redeem(uint256 _share) external;
}