// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEcliptic {
    function transferPoint(uint32, address, bool) external;
    function spawn(uint32, address) external;
}
