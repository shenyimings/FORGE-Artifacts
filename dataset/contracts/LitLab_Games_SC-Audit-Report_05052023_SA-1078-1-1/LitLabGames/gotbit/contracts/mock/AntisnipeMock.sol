//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title AntisnipeMock
 * @author gotbit
 */

import {IAntisnipe} from '../LitlabToken.sol';

contract AntisnipeMock is IAntisnipe {
    address public lastSender;
    address public lastFrom;
    address public lastTo;
    uint256 public lastAmount;

    /// @dev mock function to check iputs
    /// @param sender caller of transfer
    /// @param from tokens sender
    /// @param to tokens recipient
    /// @param amount amount of tokens
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external {
        lastSender = sender;
        lastFrom = from;
        lastTo = to;
        lastAmount = amount;
    }
}
