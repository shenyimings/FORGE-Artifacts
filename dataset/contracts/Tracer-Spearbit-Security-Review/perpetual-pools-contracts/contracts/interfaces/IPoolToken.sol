//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

/// @title Interface for the pool tokens
interface IPoolToken {
    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;
}
