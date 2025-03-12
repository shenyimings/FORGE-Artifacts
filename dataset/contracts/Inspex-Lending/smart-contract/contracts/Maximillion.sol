pragma solidity ^0.5.16;

import "./WLBNB.sol";

/**
 * @title Welnance's Maximillion Contract
 * @author Welnance
 */
contract Maximillion {
    /**
     * @notice The default aBnb market to repay in
     */
    WLBNB public wlBnb;

    /**
     * @notice Construct a Maximillion to repay max in a ABNB market
     */
    constructor(WLBNB wlBnb_) public {
        wlBnb = wlBnb_;
    }

    /**
     * @notice msg.sender sends BNB to repay an account's borrow in the aBnb market
     * @dev The provided BNB is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     */
    function repayBehalf(address borrower) public payable {
        repayBehalfExplicit(borrower, wlBnb);
    }

    /**
     * @notice msg.sender sends BNB to repay an account's borrow in a aBnb market
     * @dev The provided BNB is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     * @param wlBnb_ The address of the aBnb contract to repay in
     */
    function repayBehalfExplicit(address borrower, WLBNB wlBnb_) public payable {
        uint received = msg.value;
        uint borrows = wlBnb_.borrowBalanceCurrent(borrower);
        if (received > borrows) {
            wlBnb_.repayBorrowBehalf.value(borrows)(borrower);
            msg.sender.transfer(received - borrows);
        } else {
            wlBnb_.repayBorrowBehalf.value(received)(borrower);
        }
    }
}
