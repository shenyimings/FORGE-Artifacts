// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IForwarderRegistry {
    function isForwarderFor(address, address) external view returns (bool);
}
