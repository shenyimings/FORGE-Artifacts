// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

contract LogicA {
    uint256 public valueUint;
    address public owner;

    function initialize() public {
        valueUint = 42;
        owner = msg.sender;
    }
}

contract LogicB {
    uint256 public valueUint;
    address public owner;

    function initialize(address _owner, uint256 meaning) public {
        valueUint = meaning;
        owner = _owner;
    }

    function setMeaning(uint256 meaning) public {
        valueUint = meaning;
    }
}
