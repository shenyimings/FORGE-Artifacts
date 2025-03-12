/*
 * SPDX-License-Identifier:    MIT
 */

pragma solidity ^0.5.17;


interface IPaymentsBook {
    /**
    * @dev Pay an amount of tokens
    * @param _token Address of the token being paid
    * @param _amount Amount of tokens being paid
    * @param _payer Address paying on behalf of
    * @param _data Optional data
    */
    function pay(address _token, uint256 _amount, address _payer, bytes calldata _data) external payable;
}
