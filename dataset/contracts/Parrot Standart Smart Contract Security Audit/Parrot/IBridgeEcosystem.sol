// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

interface IBridgeEcosystem {
    function isWhitelisted(address token) external returns (bool);
}