// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface ICrystalToken {
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}