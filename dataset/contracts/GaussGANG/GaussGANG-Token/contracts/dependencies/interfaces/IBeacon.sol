// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;



// This is the interface that {BeaconProxy} expects of its beacon.
interface IBeacon {
    
    //Must return an address that can be used as a delegate call target. {BeaconProxy} will check that this address is a contract.
    function implementation() external view returns (address);
}