    //SPDX-License-Identifier: MIT
    pragma solidity 0.8.5;



    // ----------------------------------------------------------------------------

    // Owned contract

    // ----------------------------------------------------------------------------

    abstract contract Owned {

        address public owner;

        address public newOwner;


        event OwnershipTransferred(address indexed _from, address indexed _to);


        constructor() {

            owner = msg.sender;

        }


        modifier onlyOwner {

            require(msg.sender == owner);

            _;

        }


        function transferOwnership(address _newOwner) public onlyOwner {

            require(_newOwner != address(0), "Invalid address");

            newOwner = _newOwner;

        }

        function acceptOwnership() external {

            require(msg.sender == newOwner);

            emit OwnershipTransferred(owner, newOwner);

            owner = newOwner;

            newOwner = address(0);

        }

    }

