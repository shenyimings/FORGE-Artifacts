pragma solidity ^0.5.16;

import "./CWrappedNative.sol";

/**
 * @title Compound's Maximillion Contract
 * @author Compound
 */
contract Maximillion {
    /**
     * @notice The CWrappedNative market to repay in
     */
    CWrappedNative public cWrappedNative;

    /**
     * @notice Construct a Maximillion to repay max in a CWrappedNative market
     */
    constructor(CWrappedNative cWrappedNative_) public {
        cWrappedNative = cWrappedNative_;
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in the cWrappedNative market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     */
    function repayBehalf(address borrower) public payable {
        repayBehalfExplicit(borrower, cWrappedNative);
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in a cWrappedNative market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     * @param cWrappedNative_ The address of the cWrappedNative contract to repay in
     */
    function repayBehalfExplicit(address borrower, CWrappedNative cWrappedNative_) public payable {
        uint256 received = msg.value;
        uint256 borrows = cWrappedNative_.borrowBalanceCurrent(borrower);
        if (received > borrows) {
            cWrappedNative_.repayBorrowBehalfNative.value(borrows)(borrower);
            msg.sender.transfer(received - borrows);
        } else {
            cWrappedNative_.repayBorrowBehalfNative.value(received)(borrower);
        }
    }
}
