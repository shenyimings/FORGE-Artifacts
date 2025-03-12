// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IPause {
    function pause() external;
    function unpause() external;
}
