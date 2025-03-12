// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

import "./PToken/PEther/PEther.sol";

/**
 * @title Compound's Maximillion Contract
 * @author Compound, Paribus
 */
contract Maximillion {
    /**
     * @notice The default pEther market to repay in
     */
    PEther public pEther;

    /**
     * @notice Construct a Maximillion to repay max in a PEther market
     */
    constructor(PEther pEther_) public {
        pEther = pEther_;
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in the pEther market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     */
    function repayBehalf(address borrower) external payable {
        repayBehalfExplicit(borrower, pEther);
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in a pEther market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     * @param pEther_ The address of the pEther contract to repay in
     */
    function repayBehalfExplicit(address borrower, PEther pEther_) public payable {
        uint received = msg.value;
        uint borrows = pEther_.borrowBalanceCurrent(borrower);

        if (received > borrows) {
            pEther_.repayBorrowBehalf.value(borrows)(borrower);
            (bool success, ) = msg.sender.call.value(received - borrows)("");
            require(success, "Transfer failed.");
        } else {
            pEther_.repayBorrowBehalf.value(received)(borrower);
        }
    }
}
