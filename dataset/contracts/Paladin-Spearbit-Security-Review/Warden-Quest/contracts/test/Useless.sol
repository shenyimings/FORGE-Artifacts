// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Useless contract used for tests
 */
contract Useless {
    
    bool public called;

    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
        called = true;
    }

    function reset() external {
        value = 0;
        called = false;
    }
    
}