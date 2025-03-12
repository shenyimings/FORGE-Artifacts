// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ISToken
 *
 * @notice ISToken is a spear/shield that can be minted and burned by the battle contract.
 */
interface ISToken {
    /**
     * @notice Mint `amount` of ISToken to `account`
     */
    function mint(address account, uint256 amount) external;
    /**
     * @notice Burn `amount` of ISToken from `account`
     */
    function burn(address account, uint256 amount) external;
}
