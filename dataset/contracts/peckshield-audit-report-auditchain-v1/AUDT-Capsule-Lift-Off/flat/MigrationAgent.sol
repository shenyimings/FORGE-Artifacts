pragma solidity ^0.6.6;

// SPDX-License-Identifier: MIT


/// @title Migration Agent interface
abstract contract MigrationAgent {

    function migrateFrom(address _from, uint256 _value) public virtual;
}