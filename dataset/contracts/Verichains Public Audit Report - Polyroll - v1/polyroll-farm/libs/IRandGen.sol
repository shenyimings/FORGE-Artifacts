// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRandGen {
    function getRandomNumber(uint userProvidedSeed) external returns (bytes32);
}