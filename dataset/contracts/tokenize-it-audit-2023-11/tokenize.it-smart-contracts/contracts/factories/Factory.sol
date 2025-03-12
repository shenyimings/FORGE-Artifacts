// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @title Factory
 * @author malteish
 * @notice inherit from this contract to create a factory for a specific contract
 */

abstract contract Factory {
    /// The address of the implementation contract
    address immutable implementation;

    constructor(address _implementation) {
        require(_implementation != address(0), "Factory: implementation can not be zero");
        implementation = _implementation;
    }
}
