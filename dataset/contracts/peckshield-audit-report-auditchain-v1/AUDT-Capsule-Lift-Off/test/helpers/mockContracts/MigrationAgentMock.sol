pragma solidity ^0.6.0;

import "../../../contracts/MigrationAgent.sol";

/// @title Migration Agent interface
contract MigrationAgentMock {

    mapping(address => uint) public balances;

    event AgentDeployed(address user);


    constructor () public {

        emit AgentDeployed(msg.sender);
    }

    function migrateFrom(address _from, uint256 _value) public {

        balances[_from] = _value;
        
    }
}