// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IEcosystem {
    function isWhitelisted(address token) external returns (bool);
}