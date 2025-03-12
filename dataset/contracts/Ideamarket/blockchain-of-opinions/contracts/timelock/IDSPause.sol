// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IDSPause
 * @author Alexander Schlindwein
 *
 * @dev Interface for the timelock
 */
interface IDSPause {
    function setOwner(address owner) external;
    function setDelay(uint delay) external;
    function soul(address usr) external view returns (bytes32 tag);
    function plot(address usr, bytes32 tag, bytes memory fax, uint eta) external;
    function drop(address usr, bytes32 tag, bytes memory fax, uint eta) external;
    function exec(address usr, bytes32 tag, bytes memory fax, uint eta) external returns (bytes memory out);
}

