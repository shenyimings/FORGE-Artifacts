// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @title Interface for plus token.
 * Plus token is a value pegged ERC20 token which provides global interest to all holders.
 */
interface IPlus {
    /**
     * @dev Returns the governance address.
     */
    function governance() external view returns (address);

    /**
     * @dev Returns whether the account is a strategist.
     */
    function strategists(address _account) external view returns (bool);

    /**
     * @dev Returns the treasury address.
     */
    function treasury() external view returns (address);

    /**
     * @dev Accrues interest to increase index.
     */
    function rebase() external;

    /**
     * @dev Returns the total value of the plus token in terms of the peg value.
     */
    function totalUnderlying() external view returns (uint256);

    /**
     * @dev Allows anyone to donate their plus asset to all other holders.
     * @param _amount Amount of plus token to donate.
     */
    function donate(uint256 _amount) external;
}