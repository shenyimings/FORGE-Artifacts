// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IMintBurn {

    function burn(address account, uint amount) external;
    function mint(address account, uint amount) external;
}