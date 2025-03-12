// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRPSRouter {
    function setRaffleAddress(address _raffle) external;
    function migrateProtocol(address _newProtocolAddress) external; 

    event ProtocolMigrated(address _newProtocolAddress); 
}