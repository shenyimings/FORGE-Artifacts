// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

interface INimfToken {
    function mint(address, uint256) external returns (bool);

    function burn(uint256) external;

    function burnFrom(address, uint256) external;
}
