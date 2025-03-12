// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Ownable {

    // We have owner account is for receiving the fee
    address payable public owner;

    event OwnershipTransferred(address previousOwner, address newOwner);

    modifier isOwner() {
        require(msg.sender == owner, "Must be the owner of the contract.");
        _;
    }

    function transferOwnership(address payable newOwner) public isOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}