// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

/// @title Migration Agent interface
abstract contract MigrationAgent {

    function migrateFrom(address _from, uint256 _value) public virtual;
}