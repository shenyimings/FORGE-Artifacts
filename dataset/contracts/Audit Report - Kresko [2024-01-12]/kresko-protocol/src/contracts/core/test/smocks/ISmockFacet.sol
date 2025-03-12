// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface ISmockFacet {
    event NewMessage(address indexed caller, string message);

    function activate() external;

    function disable() external;

    function setMessage(string memory message) external;
}
