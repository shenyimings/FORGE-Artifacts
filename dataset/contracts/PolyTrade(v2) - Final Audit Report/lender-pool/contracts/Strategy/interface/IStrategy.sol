//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

interface IStrategy {
    /**
     * @notice Emitted when funds are deposited
     * @param amount, total amount deposited
     */
    event Deposit(uint amount);

    /**
     * @notice Emitted when funds are withdrawn from lender pool
     * @param amount, total amount withdrawn
     */
    event Withdraw(uint amount);

    /**
     * @notice transfer funds to aave lending pool
     * @dev accepts token from msg.sender and transfers to aave lending pool
     * @param amount, total amount accepted from user and transferred to aave
     */
    function deposit(uint amount) external;

    /**
     * @notice withdraw funds from aave and send to lending pool
     * @dev can be called by only lender pool
     * @param amount, total amount accepted from user and transferred to aave
     */
    function withdraw(uint amount) external;

    /**
     * @notice get aStable balance of staking strategy smart contract
     * @return total amount of aStable token in this contract
     */
    function getBalance() external view returns (uint);
}
