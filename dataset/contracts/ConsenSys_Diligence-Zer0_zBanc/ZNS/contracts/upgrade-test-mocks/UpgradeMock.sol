// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

 /* solhint-disable */
contract UpgradeMock {
    uint256 public newNumber;

    address public newAddress;

    mapping(uint256 newNumber => address newAddress) public newMapping;

    function setNewMapping(uint256 newNumber_) public {
        newMapping[newNumber_] = msg.sender;
    }

    function setNewMappingSpecific(uint256 newNumber_, address newAddress_) public {
        newMapping[newNumber_] = newAddress_;
    }

    function setNewNumber(uint256 newNumber_) public {
        newNumber = newNumber_;
    }

    function setNewAddress(address newAddress_) public {
        newAddress = newAddress_;
    }
}